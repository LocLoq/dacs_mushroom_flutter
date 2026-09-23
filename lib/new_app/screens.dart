import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'core.dart';
import 'state.dart';

enum ResourceKind { species, facility, batch, user }

final listProvider = FutureProvider.autoDispose.family<PaginatedResult<Map<String, dynamic>>, _ListRequest>((ref, request) async {
  final response = await ref.read(apiClientProvider).get(request.endpoint, query: {
    'page': request.page, 'limit': 20, if (request.search.isNotEmpty) 'search': request.search,
  });
  final root = Map<String, dynamic>.from(response.data as Map);
  final raw = (root['data'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  return PaginatedResult(raw, Pagination.fromJson(root['pagination'] as Map<String, dynamic>?));
});
class _ListRequest { const _ListRequest(this.endpoint, this.page, this.search); final String endpoint; final int page; final String search;
  @override bool operator ==(Object other) => other is _ListRequest && other.endpoint == endpoint && other.page == page && other.search == search;
  @override int get hashCode => Object.hash(endpoint, page, search);
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.returnTo}); final String? returnTo;
  @override ConsumerState<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>(); final _username = TextEditingController(); final _password = TextEditingController(); bool _hide = true;
  @override void dispose() { _username.dispose(); _password.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(body: Center(child: SingleChildScrollView(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430), child: Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.eco_rounded, size: 60, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 12),
      Text('Quản lý Sản xuất & Nhận diện Nấm', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
      const SizedBox(height: 24), Form(key: _form, child: Column(children: [
        TextFormField(controller: _username, autofocus: true, decoration: const InputDecoration(labelText: 'Tên đăng nhập'), validator: _required), const SizedBox(height: 14),
        TextFormField(controller: _password, obscureText: _hide, decoration: InputDecoration(labelText: 'Mật khẩu', suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _hide = !_hide))), validator: _required, onFieldSubmitted: (_) => _login()),
      ])), const SizedBox(height: 20),
      if (auth.hasError) ErrorText(error: auth.error!),
      FilledButton.icon(onPressed: auth.isLoading ? null : _login, icon: auth.isLoading ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login), label: const Text('Đăng nhập')),
      const SizedBox(height: 12), Wrap(alignment: WrapAlignment.center, spacing: 4, children: [TextButton(onPressed: () => context.go('/classify'), child: const Text('Nhận diện với tư cách khách')), TextButton(onPressed: () => context.go('/lookup'), child: const Text('Tra cứu lô công khai'))]),
    ])))))));
  }
  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Vui lòng nhập trường này.' : null;
  void _login() { if (_form.currentState!.validate()) ref.read(authProvider.notifier).login(_username.text.trim(), _password.text); }
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child}); final Widget child;
  @override Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider).asData?.value; final wide = MediaQuery.sizeOf(context).width >= 800;
    final items = <_Nav>[const _Nav('Tổng quan', '/', Icons.dashboard_outlined), const _Nav('Lô nuôi trồng', '/batches', Icons.inventory_2_outlined), const _Nav('Giống nấm', '/species', Icons.spa_outlined), const _Nav('Cơ sở', '/facilities', Icons.warehouse_outlined), if (canManage(session?.role)) const _Nav('Báo cáo', '/reports', Icons.bar_chart_outlined), if (canManage(session?.role)) const _Nav('Nhật ký audit', '/audit', Icons.history_outlined), if (isAdmin(session?.role)) const _Nav('Người dùng', '/users', Icons.people_outline), const _Nav('Nhận diện AI', '/classify', Icons.auto_awesome_outlined), const _Nav('Cài đặt', '/settings', Icons.settings_outlined)];
    final body = Row(children: [if (wide) NavigationRail(extended: MediaQuery.sizeOf(context).width >= 1120, selectedIndex: _selected(context, items), labelType: NavigationRailLabelType.all, leading: const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Icon(Icons.eco_rounded, size: 32)), destinations: items.map((e) => NavigationRailDestination(icon: Icon(e.icon), label: Text(e.label))).toList(), onDestinationSelected: (i) => context.go(items[i].path)), Expanded(child: child)]);
    return Scaffold(body: SafeArea(child: body), bottomNavigationBar: wide ? null : NavigationBar(selectedIndex: _selected(context, items).clamp(0, 3), onDestinationSelected: (i) => context.go(items[i].path), destinations: items.take(4).map((e) => NavigationDestination(icon: Icon(e.icon), label: e.label)).toList()));
  }
  int _selected(BuildContext context, List<_Nav> items) { final path = GoRouterState.of(context).matchedLocation; final i = items.indexWhere((e) => e.path == path); return i < 0 ? 0 : i; }
}
class _Nav { const _Nav(this.label, this.path, this.icon); final String label,path; final IconData icon; }

class PageFrame extends StatelessWidget { const PageFrame({super.key, required this.title, required this.child, this.actions}); final String title; final Widget child; final List<Widget>? actions;
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title), actions: actions), body: SafeArea(child: child)); }
class ErrorText extends StatelessWidget { const ErrorText({super.key, required this.error}); final Object error;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(error is ApiException ? (error as ApiException).message : 'Đã xảy ra lỗi. Vui lòng thử lại.', style: TextStyle(color: Theme.of(context).colorScheme.error))); }

class DashboardScreen extends ConsumerWidget { const DashboardScreen({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) { final session = ref.watch(authProvider).asData?.value; final overview = canManage(session?.role) ? ref.watch(overviewProvider) : null;
    return PageFrame(title: 'Tổng quan', actions: [IconButton(onPressed: () => ref.read(authProvider.notifier).logout(), icon: const Icon(Icons.logout), tooltip: 'Đăng xuất')], child: ListView(padding: const EdgeInsets.all(20), children: [
      Text('Chào ${session?.username ?? ''}', style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 6), Text(session?.role.label ?? ''), const SizedBox(height: 20),
      if (overview != null) overview.when(data: (data) => OverviewCards(data: data), loading: () => const Center(child: CircularProgressIndicator()), error: (e, _) => ErrorText(error: e)) else const _StaffDashboard(),
    ])); }
}
final overviewProvider = FutureProvider.autoDispose<Map<String,dynamic>>((ref) async => Map<String,dynamic>.from((await ref.read(apiClientProvider).get('/reports/overview')).data['data'] as Map));
class OverviewCards extends StatelessWidget {
  const OverviewCards({super.key, required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final cultivation = Map<String, dynamic>.from(data['cultivation'] as Map? ?? {});
    final classifier = Map<String, dynamic>.from(data['classifier'] as Map? ?? {});
    final cards = <(String, Object?)>[
      ('Cơ sở', cultivation['facilities']), ('Giống nấm', cultivation['species']),
      ('Lô nuôi trồng', cultivation['batchCount']), ('Thu hoạch (kg)', cultivation['totalHarvestKg']),
      ('AI thành công', classifier['succeeded']),
    ];
    final harvest = (cultivation['harvestSeries'] as List? ?? const []).take(12).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 12, runSpacing: 12, children: cards.map((entry) => SizedBox(width: 190, child: Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(entry.$1), const SizedBox(height: 8), Text('${entry.$2 ?? 0}', style: Theme.of(context).textTheme.headlineSmall)]))))).toList()),
      const SizedBox(height: 24),
      SizedBox(height: 190, child: Card(child: Padding(padding: const EdgeInsets.all(16), child: BarChart(BarChartData(titlesData: const FlTitlesData(show: false), borderData: FlBorderData(show: false), barGroups: harvest.asMap().entries.map((entry) { final row = entry.value as Map; return BarChartGroupData(x: entry.key, barRods: [BarChartRodData(toY: (row['totalHarvestKg'] as num?)?.toDouble() ?? 0, color: Theme.of(context).colorScheme.primary)]); }).toList()))))),
    ]);
  }
}
class _StaffDashboard extends StatelessWidget { const _StaffDashboard(); @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Không gian làm việc', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 8), const Text('Theo dõi lô nuôi trồng, nhật ký chăm sóc, sinh trưởng và thu hoạch từ thanh điều hướng.')]))); }

class ResourceScreen extends ConsumerStatefulWidget { const ResourceScreen({super.key, required this.title, required this.endpoint, required this.kind}); final String title, endpoint; final ResourceKind kind;
  @override ConsumerState<ResourceScreen> createState() => _ResourceScreenState(); }
class _ResourceScreenState extends ConsumerState<ResourceScreen> { final _search = TextEditingController(); int _page = 1;
  @override void dispose() { _search.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) { final role = ref.watch(authProvider).asData?.value?.role; final editable = widget.kind == ResourceKind.user ? isAdmin(role) : canManage(role); final req = _ListRequest(widget.endpoint, _page, _search.text); final state = ref.watch(listProvider(req));
    return PageFrame(title: widget.title, actions: [if (editable) IconButton(onPressed: () => _edit(context, null), icon: const Icon(Icons.add), tooltip: 'Tạo mới')], child: Column(children: [Padding(padding: const EdgeInsets.all(16), child: TextField(controller: _search, decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Tìm kiếm', suffixIcon: IconButton(icon: const Icon(Icons.clear), onPressed: () { _search.clear(); setState(() => _page = 1); })), onChanged: (_) => Future<void>.delayed(const Duration(milliseconds: 350), () { if (mounted) setState(() => _page = 1); }))), Expanded(child: state.when(loading: () => const Center(child: CircularProgressIndicator()), error: (e,_) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [ErrorText(error: e), FilledButton(onPressed: () => ref.invalidate(listProvider(req)), child: const Text('Thử lại'))])), data: (result) => _results(context, result, editable, req))), ])); }
  Widget _results(BuildContext context, PaginatedResult<Map<String,dynamic>> result, bool editable, _ListRequest req) {
    if (result.items.isEmpty) return const Center(child: Text('Chưa có dữ liệu.'));
    return Column(children: [
      Expanded(child: ListView.separated(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), itemCount: result.items.length, separatorBuilder: (_, index) => const SizedBox(height: 8), itemBuilder: (_, index) {
        final item = result.items[index];
        return Card(child: ListTile(title: Text(_title(item)), subtitle: Text(_subtitle(item)), trailing: Wrap(children: [
          IconButton(icon: const Icon(Icons.visibility_outlined), onPressed: () => _showJson(context, item)),
          if (widget.kind == ResourceKind.batch) IconButton(icon: const Icon(Icons.article_outlined), onPressed: () => _batchDetail(context, item)),
          if (editable) IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(context, item)),
          if (editable) IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(context, item, req)),
        ])));
      })),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('${result.pagination.total} bản ghi'), IconButton(onPressed: _page > 1 ? () => setState(() => _page--) : null, icon: const Icon(Icons.chevron_left)), Text('${result.pagination.page}/${result.pagination.totalPages}'), IconButton(onPressed: result.pagination.hasMore ? () => setState(() => _page++) : null, icon: const Icon(Icons.chevron_right))]),
    ]);
  }
  String _title(Map<String,dynamic> item) => switch(widget.kind) { ResourceKind.species => '${item['commonName'] ?? ''} (${item['scientificName'] ?? ''})', ResourceKind.facility => item['name']?.toString() ?? '', ResourceKind.batch => item['batchCode']?.toString() ?? '', ResourceKind.user => item['username']?.toString() ?? '' };
  String _subtitle(Map<String,dynamic> item) => switch(widget.kind) { ResourceKind.species => '${item['family'] ?? ''} · ${item['edibilityStatus'] ?? ''}', ResourceKind.facility => '${item['province'] ?? ''} · ${item['status'] ?? ''}', ResourceKind.batch => '${(item['facility'] as Map?)?['name'] ?? ''} · ${item['status'] ?? ''}', ResourceKind.user => '${item['full_name'] ?? ''} · ${(item['role'] as Map?)?['name'] ?? ''}' };
  void _showJson(BuildContext context, Map<String,dynamic> item) => showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Chi tiết'), content: SingleChildScrollView(child: SelectableText(jsonText(item))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng'))]));
  Future<void> _delete(BuildContext context, Map<String,dynamic> item, _ListRequest request) async { final yes = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Xóa bản ghi?'), content: const Text('Thao tác này không thể hoàn tác.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa'))])); if (yes != true || !mounted) return; try { await ref.read(apiClientProvider).delete('${widget.endpoint}/${item['id']}'); ref.invalidate(listProvider(request)); } on ApiException catch(e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message))); } }
  void _edit(BuildContext context, Map<String,dynamic>? item) => showDialog(context: context, builder: (_) => _ResourceEditor(kind: widget.kind, endpoint: widget.endpoint, item: item, onSaved: () => ref.invalidate(listProvider(_ListRequest(widget.endpoint,_page,_search.text)))));
  void _batchDetail(BuildContext context, Map<String,dynamic> item) => showDialog(context: context, builder: (_) => BatchDetailDialog(batchId: item['id'].toString(), batchCode: item['batchCode']?.toString() ?? ''));
}

class _ResourceEditor extends ConsumerStatefulWidget { const _ResourceEditor({required this.kind, required this.endpoint, required this.item, required this.onSaved}); final ResourceKind kind; final String endpoint; final Map<String,dynamic>? item; final VoidCallback onSaved; @override ConsumerState<_ResourceEditor> createState()=>_ResourceEditorState(); }
class _ResourceEditorState extends ConsumerState<_ResourceEditor> { final form = GlobalKey<FormState>(); final values=<String,TextEditingController>{}; bool saving=false;
  List<String> get fields => switch(widget.kind) { ResourceKind.species => ['commonName','scientificName','family','genus','edibilityStatus','habitat','cultivationDifficulty','imageUrl'], ResourceKind.facility => ['name','address','province','facilityType','status','taxCode','contactPhone','contactEmail','capacityTonsPerYear','totalAreaSqm','certifications'], ResourceKind.batch => ['batchCode','facilityId','mushroomId','startDate','expectedHarvestDate','endDate','status','substrateType','spawnSource','bagQuantity','defectRate','notes'], ResourceKind.user => ['username','password','full_name','phone_number','email','role_id'] };
  @override void initState(){super.initState(); for(final f in fields) { final v=widget.item?[f]; values[f]=TextEditingController(text: v?.toString() ?? ''); }} @override void dispose(){for(final c in values.values)c.dispose();super.dispose();}
  @override Widget build(BuildContext context) => AlertDialog(title: Text(widget.item == null ? 'Tạo mới' : 'Chỉnh sửa'), content: SizedBox(width: 550, child: SingleChildScrollView(child: Form(key:form, child: Column(mainAxisSize:MainAxisSize.min, children: fields.map((f)=>Padding(padding:const EdgeInsets.only(bottom:12), child: TextFormField(controller:values[f], decoration:InputDecoration(labelText:f), maxLines:f=='notes'?3:1, validator:(v)=>_required(f)&& (v==null||v.trim().isEmpty)?'Bắt buộc':null))).toList())))), actions:[TextButton(onPressed:saving?null:()=>Navigator.pop(context),child:const Text('Hủy')), FilledButton(onPressed:saving?null:_save,child:Text(saving?'Đang lưu':'Lưu'))]);
  bool _required(String f)=> widget.item==null && switch(widget.kind){ResourceKind.species=>['commonName','scientificName','family','genus','edibilityStatus'].contains(f),ResourceKind.facility=>['name','address','facilityType'].contains(f),ResourceKind.batch=>['batchCode','facilityId','mushroomId','startDate'].contains(f),ResourceKind.user=>['username','password','full_name','phone_number','email','role_id'].contains(f)};
  Future<void> _save() async {if(!form.currentState!.validate())return; setState(()=>saving=true); final data=<String,dynamic>{}; for(final e in values.entries){if(e.value.text.trim().isNotEmpty)data[e.key]=e.value.text.trim();} for(final key in ['capacityTonsPerYear','totalAreaSqm','bagQuantity','defectRate','role_id']) {if(data[key]!=null)data[key]=num.tryParse(data[key])??data[key];} try {if(widget.item==null) await ref.read(apiClientProvider).post(widget.endpoint,data:data); else await ref.read(apiClientProvider).put('${widget.endpoint}/${widget.item!['id']}',data:data); widget.onSaved(); if(mounted)Navigator.pop(context);} on ApiException catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.message)));} finally{if(mounted)setState(()=>saving=false);} }
}

class BatchDetailDialog extends ConsumerStatefulWidget { const BatchDetailDialog({super.key, required this.batchId, required this.batchCode}); final String batchId,batchCode; @override ConsumerState<BatchDetailDialog> createState()=>_BatchDetailDialogState(); }
class _BatchDetailDialogState extends ConsumerState<BatchDetailDialog> with SingleTickerProviderStateMixin { late final TabController tabs; @override void initState(){super.initState();tabs=TabController(length:4,vsync:this);} @override void dispose(){tabs.dispose();super.dispose();}
  @override Widget build(BuildContext context) => Dialog(child: SizedBox(width: 850,height:650,child: Column(children:[AppBar(title:Text('Lô ${widget.batchCode}'),automaticallyImplyLeading:false,actions:[IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close))],bottom:TabBar(controller:tabs,tabs:const [Tab(text:'Tổng quan'),Tab(text:'Chăm sóc'),Tab(text:'Sinh trưởng'),Tab(text:'Thu hoạch')])),Expanded(child:TabBarView(controller:tabs,children:[_JsonEndpoint(path:'/cultivation-batches/${widget.batchId}'),_LogTab(batchId:widget.batchId,type:_LogType.care),_LogTab(batchId:widget.batchId,type:_LogType.growth),_LogTab(batchId:widget.batchId,type:_LogType.harvest)]))])));
}
class _JsonEndpoint extends ConsumerWidget { const _JsonEndpoint({required this.path});final String path; @override Widget build(BuildContext context,WidgetRef ref){final data=ref.watch(_endpointProvider(path));return data.when(data:(value)=>SingleChildScrollView(padding:const EdgeInsets.all(18),child:SelectableText(jsonText(value))),loading:()=>const Center(child:CircularProgressIndicator()),error:(e,_)=>Center(child:ErrorText(error:e)));}}
final _endpointProvider=FutureProvider.autoDispose.family<Object?,String>((ref,path) async => (await ref.read(apiClientProvider).get(path)).data['data']);
enum _LogType { care, growth, harvest }
class _LogTab extends ConsumerStatefulWidget { const _LogTab({required this.batchId,required this.type});final String batchId;final _LogType type;@override ConsumerState<_LogTab>createState()=>_LogTabState();}
class _LogTabState extends ConsumerState<_LogTab> {
  late String path;
  @override void initState() { super.initState(); path = '/cultivation-batches/${widget.batchId}/${switch(widget.type) {_LogType.care => 'care-logs', _LogType.growth => 'growth-progress', _LogType.harvest => 'harvest-records'}}'; }
  @override Widget build(BuildContext context) {
    final role = ref.watch(authProvider).asData?.value?.role;
    final data = ref.watch(_endpointProvider(path));
    return Column(children: [Expanded(child: data.when(data: (value) {
      final rows = value is List ? value : const <dynamic>[];
      if (rows.isEmpty) return const Center(child: Text('Chưa có nhật ký.'));
      return ListView.builder(itemCount: rows.length, itemBuilder: (_, index) {
        final item = Map<String, dynamic>.from(rows[index] as Map);
        return ListTile(title: Text(_label(item)), subtitle: Text(item['recordedAt']?.toString() ?? ''), onTap: () => showDialog(context: context, builder: (_) => AlertDialog(content: SelectableText(jsonText(item)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng'))])));
      });
    }, loading: () => const Center(child: CircularProgressIndicator()), error: (e, _) => Center(child: ErrorText(error: e)))), if (role != null) Padding(padding: const EdgeInsets.all(12), child: FilledButton.icon(onPressed: () => _add(context), icon: const Icon(Icons.add), label: const Text('Thêm nhật ký')))]);
  }
 String _label(Map<String,dynamic> item)=>switch(widget.type){_LogType.care=>'${item['actionType']??''} — ${item['notes']??''}',_LogType.growth=>'${item['stage']??''} — ${item['notes']??''}',_LogType.harvest=>'${item['totalYieldKg']??0} kg — ${item['qualityGrade']??''}'};
 void _add(BuildContext context)=>showDialog(context:context,builder:(_)=>_LogEditor(path:path,type:widget.type,onSaved:()=>ref.invalidate(_endpointProvider(path))));}
class _LogEditor extends ConsumerStatefulWidget{const _LogEditor({required this.path,required this.type,required this.onSaved});final String path;final _LogType type;final VoidCallback onSaved;@override ConsumerState<_LogEditor>createState()=>_LogEditorState();}
class _LogEditorState extends ConsumerState<_LogEditor>{final form=GlobalKey<FormState>();final first=TextEditingController();final notes=TextEditingController();bool finalize=false,saving=false;List<MediaInput> media=[];@override void dispose(){first.dispose();notes.dispose();super.dispose();}
 @override Widget build(BuildContext context){final isCare=widget.type==_LogType.care;final isGrowth=widget.type==_LogType.growth;return AlertDialog(title:const Text('Thêm nhật ký'),content:SizedBox(width:480,child:SingleChildScrollView(child:Form(key:form,child:Column(mainAxisSize:MainAxisSize.min,children:[TextFormField(controller:first,decoration:InputDecoration(labelText:isCare?'Loại công việc':isGrowth?'Giai đoạn':'Sản lượng (kg)'),keyboardType:isCare||isGrowth?TextInputType.text:const TextInputType.numberWithOptions(decimal:true),validator:(v){if(v==null||v.trim().isEmpty)return'Bắt buộc';if(!isCare&&!isGrowth&&(num.tryParse(v)??0)<=0)return'Phải lớn hơn 0';return null;}),const SizedBox(height:12),if(!isCare)TextFormField(controller:notes,decoration:InputDecoration(labelText:isGrowth?'Ghi chú':'Ghi chú / cấp chất lượng'),maxLines:2),if(isGrowth)OutlinedButton.icon(onPressed:_pick,icon:const Icon(Icons.image_outlined),label:Text('Ảnh (${media.length}/5)')),if(!isCare&&!isGrowth)SwitchListTile(value:finalize,onChanged:(v)=>setState(()=>finalize=v),title:const Text('Hoàn tất lô'))])))),actions:[TextButton(onPressed:saving?null:()=>Navigator.pop(context),child:const Text('Hủy')),FilledButton(onPressed:saving?null:_save,child:Text(saving?'Đang lưu':'Lưu'))]);}
 Future<void>_pick()async{final result=await FilePicker.pickFiles(type:FileType.custom,allowedExtensions:['jpg','jpeg','png','webp']);final input=<MediaInput>[];for(final f in result){final bytes=await f.readAsBytes();if(bytes.lengthInBytes<=5*1024*1024)input.add(MediaInput(name:f.name,bytes:bytes,mimeType:_mime(f.name)));}if(mounted)setState(()=>media=[...media,...input].take(5).toList());}String _mime(String n){final lower=n.toLowerCase();return lower.endsWith('.png')?'image/png':lower.endsWith('.webp')?'image/webp':'image/jpeg';}
 Future<void>_save()async{if(!form.currentState!.validate())return;setState(()=>saving=true);try{if(widget.type==_LogType.growth&&media.isNotEmpty){final data=FormData.fromMap({'stage':first.text.trim(),'notes':notes.text.trim(),'images':media.map((m)=>MultipartFile.fromBytes(m.bytes,filename:m.name,contentType:DioMediaType.parse(m.mimeType))).toList()});await ref.read(apiClientProvider).post(widget.path,data:data);}else{final body=widget.type==_LogType.care?{'actionType':first.text.trim(),'notes':notes.text.trim()}:widget.type==_LogType.growth?{'stage':first.text.trim(),'notes':notes.text.trim()}:{'totalYieldKg':num.parse(first.text),'qualityGrade':notes.text.trim(),'finalizeBatch':finalize};await ref.read(apiClientProvider).post(widget.path,data:body);}widget.onSaved();if(mounted)Navigator.pop(context);}on ApiException catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.message)));}finally{if(mounted)setState(()=>saving=false);}}
}

class PublicGrowthScreen extends ConsumerStatefulWidget { const PublicGrowthScreen({super.key}); @override ConsumerState<PublicGrowthScreen> createState()=>_PublicGrowthScreenState();}
class _PublicGrowthScreenState extends ConsumerState<PublicGrowthScreen>{final code=TextEditingController();Future<Map<String,dynamic>>? future;@override void dispose(){code.dispose();super.dispose();}@override Widget build(BuildContext context)=>PageFrame(title:'Tra cứu tiến trình',child:Padding(padding:const EdgeInsets.all(20),child:Column(children:[TextField(controller:code,decoration:InputDecoration(labelText:'Mã lô',suffixIcon:IconButton(icon:const Icon(Icons.search),onPressed:_search)),onSubmitted:(_)=>_search()),const SizedBox(height:20),if(future!=null)Expanded(child:FutureBuilder(future:future,builder:(context,snapshot){if(snapshot.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());if(snapshot.hasError)return Center(child:ErrorText(error:snapshot.error!));final data=snapshot.data!;return ListView(children:[Text(data['batchCode']?.toString()??'',style:Theme.of(context).textTheme.headlineSmall),Text('${data['mushroom']?['commonName']??''} · ${data['facility']?['name']??''}'),const SizedBox(height:16),SelectableText(jsonText(data))]);}))])));void _search(){final value=code.text.trim();if(value.isEmpty)return;setState(()=>future=ref.read(apiClientProvider).get('/public/cultivation-batches/$value/growth-progress/current',auth:RequestAuth.none).then((r)=>Map<String,dynamic>.from(r.data['data']as Map)));}}

class ClassifierScreen extends ConsumerStatefulWidget { const ClassifierScreen({super.key}); @override ConsumerState<ClassifierScreen> createState()=>_ClassifierScreenState();}
class _ClassifierScreenState extends ConsumerState<ClassifierScreen>{MediaInput? image;String? jobId;Map<String,dynamic>? result;String status='';io.Socket? socket;bool sending=false;@override void dispose(){socket?.dispose();super.dispose();}
 @override Widget build(BuildContext context) => PageFrame(title: 'Nhận diện AI', child: ListView(padding: const EdgeInsets.all(20), children: [
   Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
     Text('Gửi ảnh nấm để nhận diện', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 12),
     OutlinedButton.icon(onPressed: _pick, icon: const Icon(Icons.upload_file), label: Text(image?.name ?? 'Chọn ảnh JPEG, PNG hoặc WebP')),
     if (image != null) Padding(padding: const EdgeInsets.only(top: 12), child: Image.memory(image!.bytes, height: 180, fit: BoxFit.contain)),
     const SizedBox(height: 12), FilledButton.icon(onPressed: image == null || sending ? null : _classify, icon: sending ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome), label: const Text('Nhận diện')),
   ]))),
   if (status.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 16), child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('Trạng thái: $status')))),
   if (result != null) Padding(padding: const EdgeInsets.only(top: 16), child: Card(child: Padding(padding: const EdgeInsets.all(16), child: SelectableText(jsonText(result))))),
 ]));
 Future<void>_pick()async{final picked=await FilePicker.pickFiles(type:FileType.custom,allowedExtensions:['jpg','jpeg','png','webp']);if(picked.isEmpty)return;final file=picked.first;final bytes=await file.readAsBytes();if(bytes.lengthInBytes>5*1024*1024){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Ảnh tối đa 5 MB.')));return;}setState(()=>image=MediaInput(name:file.name,bytes:bytes,mimeType:file.name.toLowerCase().endsWith('.png')?'image/png':file.name.toLowerCase().endsWith('.webp')?'image/webp':'image/jpeg'));}
 Future<void>_classify()async{setState(()=>sending=true);try{final response=await ref.read(apiClientProvider).post('/mushroom-classifier/classify',auth:RequestAuth.optional,data:FormData.fromMap({'image':MultipartFile.fromBytes(image!.bytes,filename:image!.name,contentType:DioMediaType.parse(image!.mimeType))}));final data=Map<String,dynamic>.from(response.data as Map);jobId=data['jobId']?.toString();setState(()=>status=data['status']?.toString()??'QUEUED');_connect();}on ApiException catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.message)));}finally{if(mounted)setState(()=>sending=false);}}
 void _connect(){socket?.dispose();final config=ref.read(apiConfigProvider);socket=io.io(config.serverOrigin.toString(),io.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build())..onConnect((_)=>socket!.emit('subscribe_job',jobId))..on('processing',(data){final map=Map<String,dynamic>.from(data as Map);if(map['jobId'].toString()==jobId&&mounted)setState(()=>status=map['status']?.toString()??'PROCESSING');})..on('finished',(data){final map=Map<String,dynamic>.from(data as Map);if(map['jobId'].toString()==jobId&&mounted)setState((){status='SUCCEEDED';result=Map<String,dynamic>.from(map['result'] as Map);});})..on('failed',(data){final map=Map<String,dynamic>.from(data as Map);if(map['jobId'].toString()==jobId&&mounted)setState(()=>status='FAILED: ${map['message']??''}');})..connect();}
}

class ReportsScreen extends ConsumerStatefulWidget { const ReportsScreen({super.key});@override ConsumerState<ReportsScreen>createState()=>_ReportsScreenState();}
class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin{late TabController tabs;@override void initState(){super.initState();tabs=TabController(length:4,vsync:this);}@override void dispose(){tabs.dispose();super.dispose();}@override Widget build(BuildContext context)=>PageFrame(title:'Báo cáo',child:Column(children:[TabBar(controller:tabs,tabs:const[Tab(text:'Overview'),Tab(text:'Nuôi trồng'),Tab(text:'Nhận diện'),Tab(text:'Audit')]),Expanded(child:TabBarView(controller:tabs,children:const[_ReportTab('/reports/overview'),_ReportTab('/reports/cultivation'),_ReportTab('/reports/classifier'),_ReportTab('/reports/audit')]))]));}
class _ReportTab extends ConsumerWidget{const _ReportTab(this.path);final String path;@override Widget build(BuildContext context,WidgetRef ref){final data=ref.watch(_endpointProvider(path));return data.when(data:(v)=>ListView(padding:const EdgeInsets.all(18),children:[SelectableText(jsonText(v))]),loading:()=>const Center(child:CircularProgressIndicator()),error:(e,_)=>Center(child:ErrorText(error:e)));}}
class AuditScreen extends ConsumerWidget{const AuditScreen({super.key});@override Widget build(BuildContext context,WidgetRef ref){final data=ref.watch(_endpointProvider('/admin/audit-logs'));return PageFrame(title:'Nhật ký audit',child:data.when(data:(v)=>ListView(padding:const EdgeInsets.all(18),children:[SelectableText(jsonText(v))]),loading:()=>const Center(child:CircularProgressIndicator()),error:(e,_)=>Center(child:ErrorText(error:e))));}}
class SettingsScreen extends ConsumerWidget{const SettingsScreen({super.key});@override Widget build(BuildContext context,WidgetRef ref){final setting=ref.watch(settingsProvider);return PageFrame(title:'Cài đặt',child:ListView(children:[SwitchListTile(title:const Text('Chế độ tối'),value:setting.themeMode==ThemeMode.dark,onChanged:(v)=>ref.read(settingsProvider.notifier).update(setting.copyWith(themeMode:v?ThemeMode.dark:ThemeMode.light))),ListTile(title:const Text('Ngôn ngữ'),subtitle:Text(setting.locale.languageCode=='vi'?'Tiếng Việt':'English'),trailing:DropdownButton<String>(value:setting.locale.languageCode,items:const[DropdownMenuItem(value:'vi',child:Text('VI')),DropdownMenuItem(value:'en',child:Text('EN'))],onChanged:(v){if(v!=null)ref.read(settingsProvider.notifier).update(setting.copyWith(locale:Locale(v)));})),ListTile(title:const Text('Máy chủ API'),subtitle:Text(setting.backendInput),onTap:()=>_server(context,ref,setting)),ListTile(title:const Text('Đăng xuất'),leading:const Icon(Icons.logout),onTap:()=>ref.read(authProvider.notifier).logout())]));}void _server(BuildContext context,WidgetRef ref,AppSettings current){final c=TextEditingController(text:current.backendInput);showDialog(context:context,builder:(_)=>AlertDialog(title:const Text('Máy chủ API'),content:TextField(controller:c,decoration:const InputDecoration(hintText:'https://server.example/api')),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Hủy')),FilledButton(onPressed:()async{try{final cfg=ApiConfig.fromInput(c.text);await Dio(BaseOptions(baseUrl:cfg.apiBaseUri.toString())).get('/test');await ref.read(settingsProvider.notifier).update(current.copyWith(backendOverride:c.text));await ref.read(authProvider.notifier).logout();if(context.mounted)Navigator.pop(context);}catch(_){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Không thể kiểm tra máy chủ.')));}},child:const Text('Lưu'))]));}}
class ForbiddenScreen extends StatelessWidget{const ForbiddenScreen({super.key});@override Widget build(BuildContext context)=>Scaffold(body:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.lock_outline,size:48),const SizedBox(height:12),Text('Bạn không có quyền truy cập',style:Theme.of(context).textTheme.titleLarge),TextButton(onPressed:()=>context.go('/'),child:const Text('Về tổng quan'))])));}
