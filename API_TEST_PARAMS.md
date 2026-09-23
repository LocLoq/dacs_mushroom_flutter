# Tham số test API

## Xác thực

Đăng nhập để lấy Bearer token:

```http
POST /api/login
Content-Type: application/json
```

```json
{
  "username": "demo_admin",
  "password": "Demo@12345"
}
```

Trong Swagger, nhấn **Authorize** và nhập `Bearer <token>`.

| Vai trò | Username | Password |
| --- | --- | --- |
| Admin | `demo_admin` | `Demo@12345` |
| Manager | `demo_manager` | `Demo@12345` |
| Staff | `demo_staff` | `Demo@12345` |

## ID demo dùng chung

```text
facilityId: 1
mushroomId: 1
batchId: 1
batchCode: DEMO-BATCH-001
growthProgressRecordId: 1441
harvestBatchId: 66
classifierId: 00000000-0000-4000-8000-000000000001
```

## Classifier

```http
POST /api/mushroom-classifier/classify
```

- Content type: `multipart/form-data`
- Field: `image`
- File: JPEG, PNG hoặc WebP, tối đa 5 MB.

```http
GET /api/mushroom-classifier/history?page=1&limit=20&status=SUCCEEDED&from=2024-09-23&to=2026-09-23
GET /api/mushroom-classifier/history/00000000-0000-4000-8000-000000000001
```

## Reports

Tham số dùng chung:

```text
from=2024-09-23
to=2026-09-23
facilityId=1
mushroomId=1
groupBy=month
page=1
limit=20
```

```http
GET /api/reports/overview?from=2024-09-23&to=2026-09-23&groupBy=month
GET /api/reports/cultivation?facilityId=1&mushroomId=1&status=FRUITING&page=1&limit=20
GET /api/reports/classifier?from=2024-09-23&to=2026-09-23&page=1&limit=20
GET /api/reports/audit?from=2024-09-23&to=2026-09-23&page=1&limit=20
```

Export:

```http
GET /api/reports/overview/export?format=csv
GET /api/reports/cultivation/export?format=xlsx&facilityId=1
GET /api/reports/classifier/export?format=pdf
GET /api/reports/audit/export?format=csv&groupBy=month
```

`format`: `csv`, `xlsx`, hoặc `pdf`.

## Audit log

```http
GET /api/admin/audit-logs?page=1&limit=20
GET /api/admin/audit-logs?actorUserId=1&action=LOGIN&outcome=SUCCESS
GET /api/admin/audit-logs?entityType=ClassifierLookup&statusCode=200
GET /api/admin/audit-logs?from=2024-09-23&to=2026-09-23
```

## Cơ sở và giống nấm

```http
GET /api/production-facilities?page=1&limit=10&search=Demo
GET /api/production-facilities/1
GET /api/mushroom-species?page=1&limit=10&search=Nấm
```

Tạo cơ sở:

```json
{
  "name": "Cơ sở Swagger",
  "address": "Đà Lạt",
  "province": "Lâm Đồng",
  "facilityType": "HOUSEHOLD",
  "status": "ACTIVE",
  "mushrooms": [1, 2]
}
```

Tạo giống nấm:

```json
{
  "scientificName": "Swagger mushroom 2026",
  "commonName": "Nấm Swagger",
  "family": "Demo",
  "genus": "Demo",
  "edibilityStatus": "EDIBLE",
  "cultivationDifficulty": "EASY"
}
```

## Lô nuôi trồng

```http
GET /api/cultivation-batches?page=1&limit=10&facilityId=1&mushroomId=1&status=FRUITING
GET /api/cultivation-batches/1
GET /api/cultivation-batches/1/care-logs
GET /api/cultivation-batches/1/growth-progress
GET /api/cultivation-batches/66/harvests
```

Tạo lô:

```json
{
  "batchCode": "SWAGGER-BATCH-001",
  "facilityId": 1,
  "mushroomId": 1,
  "status": "PREPARATION",
  "substrateType": "Mùn cưa",
  "bagQuantity": 1000,
  "startDate": "2026-09-23T08:00:00.000Z",
  "expectedHarvestDate": "2026-11-15T08:00:00.000Z"
}
```

Thêm nhật ký chăm sóc:

```json
{
  "actionType": "WATERING",
  "notes": "Tưới nước kiểm tra từ Swagger",
  "recordedAt": "2026-09-23T08:00:00.000Z"
}
```

Thêm tiến trình sinh trưởng:

```json
{
  "stage": "INCUBATION",
  "notes": "Cập nhật từ Swagger",
  "recordedAt": "2026-09-23T08:00:00.000Z"
}
```

Sửa tiến trình `PATCH /api/cultivation-batches/1/growth-progress/1441`:

```json
{
  "stage": "FRUITING",
  "notes": "Đã bắt đầu ra quả thể"
}
```

Ghi thu hoạch `POST /api/cultivation-batches/66/harvests`:

```json
{
  "totalYieldKg": 15.5,
  "qualityGrade": "A",
  "notes": "Thu hoạch thử từ Swagger",
  "harvestedAt": "2026-09-23T08:00:00.000Z",
  "finalizeBatch": false
}
```

## Public growth progress

Không cần token:

```http
GET /api/public/cultivation-batches/DEMO-BATCH-001/growth-progress/current
```

Các batch code demo: `DEMO-BATCH-001` đến `DEMO-BATCH-100`.
