# API 명세

## 1. 개요

지하철 습득물을 검색·조회하고, 이메일 인증을 거쳐 알림 조건을 등록·조회·해지하는 API입니다. 회원가입 없이 사용하며, 권한이 필요한 기능은 용도가 제한된 토큰으로 확인합니다.

### 1.1 공통 규칙

| 항목 | 규칙 |
| --- | --- |
| 요청 형식 | Body가 있는 요청은 `Content-Type: application/json` |
| 응답 형식 | `application/json` |
| 성공·실패 판단 | HTTP 상태 코드로 판단한다. 성공 응답은 데이터를 그대로 반환하고, 실패 응답은 공통 에러 형식을 따른다 |
| 날짜 형식 | `yyyy-MM-dd` |
| 날짜·시간 형식 | `yyyy-MM-dd HH:mm:ss` |
| 시간대 | 모든 날짜·시간은 한국 표준시(KST, UTC+9) 기준 |
| 필드 이름 | camelCase. 습득물 관련 필드(`fdPrdtNm`, `csteSteNm` 등)는 원본 데이터와 대조하기 쉽도록 경찰청 API의 이름을 그대로 사용 |

### 1.2 토큰

| 토큰 | 발급 시점 | 용도 | 유효 기간 | 전달 방식 |
| --- | --- | --- | --- | --- |
| 인증 토큰 (`verToken`) | 인증번호 확인 성공 시 | 알림 조건 등록 1회 | 발급 후 30분, 1회 사용 | 요청 Body |
| 관리 토큰 (`alertToken`) | 알림 조건 등록 성공 시 (완료 메일 링크에 포함) | 해당 알림 조건의 조회·해지 | 알림 조건 만료(31일) 또는 해지 시까지 | URL 경로 |

- 인증 토큰은 1회용이므로, 한 이메일로 알림 조건을 여러 개 등록하려면 조건마다 이메일 인증을 새로 진행한다.

### 1.3 API 사용 순서

```
1. 인증번호 발송   POST   /api/verifications
2. 인증번호 확인   POST   /api/verifications/confirm   → verToken 발급
3. 알림 조건 등록  POST   /api/alerts                  → verToken 사용, 완료 메일로 관리 토큰 전달
4. 알림 조건 조회  GET    /api/alerts/{alertToken}
5. 알림 조건 해지  DELETE /api/alerts/{alertToken}
```

습득물 검색·상세 조회는 인증 없이 호출할 수 있다.

## 2. 공통 에러 응답

모든 4xx, 5xx 응답은 아래 형식을 따른다. 클라이언트는 `code`로 분기 처리하고, `message`는 화면 표시에만 사용한다. 요청 형식 오류, 없는 주소, 지원하지 않는 Method처럼 특정 API에 속하지 않는 에러도 같은 형식으로 반환한다.

```json
{
  "code": "VERIFICATION_EXPIRED",
  "message": "인증번호가 만료되었습니다. 인증번호를 다시 발송해 주세요."
}
```

| API | 상황 | status | code | message |
| --- | --- | --- | --- | --- |
| 습득물 검색 | item과 station이 모두 비어 있음 | 400 | SEARCH_CONDITION_REQUIRED | 역명이나 물품명 중 하나 이상 입력해 주세요. |
| 습득물 검색 | page가 숫자가 아니거나 1 미만 | 400 | INVALID_PAGE | 페이지 번호는 1 이상의 숫자여야 합니다. |
| 습득물 상세 조회 | 관리번호의 습득물이 없음 | 404 | ATCID_NOT_FOUND | 해당 관리번호의 습득물이 존재하지 않습니다. |
| 인증번호 발송 | 이메일이 비었거나 형식 오류 | 400 | EMAIL_INVALID | 이메일 형식이 알맞지 않습니다. 다시 입력해 주세요. |
| 인증번호 발송 | 1분 이내 재요청 | 429 | VERIFICATION_TOO_MANY_REQUESTS | 인증번호는 1분에 한 번만 받을 수 있습니다. 잠시 후 다시 시도해 주세요. |
| 인증번호 발송 | 같은 IP의 발송 한도 초과 (1시간 20회) | 429 | VERIFICATION_IP_LIMIT | 요청이 너무 많습니다. 잠시 후 다시 시도해 주세요. |
| 인증번호 발송 | 메일 발송 실패 | 503 | VERIFICATION_MAIL_SEND_FAILED | 인증번호 메일을 보내지 못했습니다. 잠시 후 다시 시도해 주세요. |
| 인증번호 확인 | 발송된 인증번호가 없음 | 401 | VERIFICATION_NOT_FOUND | 인증번호를 먼저 발송해 주세요. |
| 인증번호 확인 | 인증번호 만료 (10분 경과) | 401 | VERIFICATION_EXPIRED | 인증번호가 만료되었습니다. 인증번호를 다시 발송해 주세요. |
| 인증번호 확인 | 이미 확인을 마친 인증번호 | 401 | VERIFICATION_USED | 이미 사용된 인증번호입니다. 인증번호를 다시 발송해 주세요. |
| 인증번호 확인 | 5회 틀려서 잠김 | 401 | VERIFICATION_LOCKED | 인증번호를 5회 잘못 입력했습니다. 인증번호를 다시 발송해 주세요. |
| 인증번호 확인 | 인증번호 불일치 | 401 | VERIFICATION_MISMATCH | 인증번호가 일치하지 않습니다. 다시 확인해 주세요. |
| 알림 조건 등록 | 역과 물품명이 모두 비어 있음 | 400 | CONDITION_REQUIRED | 역명이나 물품명 중 하나 이상 입력해 주세요. |
| 알림 조건 등록 | 최대 길이 초과 | 400 | CONDITION_TOO_LONG | 역명과 물품명은 200자 이하로 입력해 주세요. |
| 알림 조건 등록 | 존재하지 않는 역 | 400 | STATION_NOT_FOUND | 존재하지 않는 역입니다. 역명을 확인해 주세요. |
| 알림 조건 등록 | 인증 토큰이 없음, 만료, 이미 사용함 | 401 | VER_TOKEN_INVALID | 인증이 만료되었거나 올바르지 않습니다. 이메일 인증을 다시 진행해 주세요. |
| 알림 조건 등록 | 같은 이메일로 같은 조건이 이미 등록되어 있음 | 409 | CONDITION_DUPLICATE | 이미 같은 조건으로 알림을 신청했습니다. |
| 알림 조건 등록 | 완료 메일 발송 실패 | 503 | ALERT_MAIL_SEND_FAILED | 등록 완료 메일을 보내지 못해 등록이 취소되었습니다. 잠시 후 다시 시도해 주세요. |
| 알림 조건 조회·해지 | 토큰의 조건이 없음 (잘못된 링크, 해지, 만료) | 404 | ALERT_NOT_FOUND | 알림 조건을 찾을 수 없습니다. 이미 해지되었거나 만료된 링크일 수 있습니다. |
| 공통 | 요청 본문이 JSON이 아니거나 비어 있음, 값의 타입·길이가 맞지 않음 | 400 | INVALID_REQUEST | 요청 형식이 올바르지 않습니다. |
| 공통 | 존재하지 않는 주소 | 404 | API_NOT_FOUND | 요청한 주소를 찾을 수 없습니다. |
| 공통 | 지원하지 않는 Method | 405 | METHOD_NOT_ALLOWED | 지원하지 않는 요청 방식입니다. |
| 공통 | Content-Type이 application/json이 아님 | 415 | UNSUPPORTED_MEDIA_TYPE | 요청 형식은 JSON만 지원합니다. |
| 공통 | 서버 오류 | 500 | INTERNAL_SERVER_ERROR | 일시적인 오류가 발생했습니다. 잠시 후 다시 시도해 주세요. |

- 공통 에러(INVALID_REQUEST, API_NOT_FOUND, METHOD_NOT_ALLOWED, UNSUPPORTED_MEDIA_TYPE, INTERNAL_SERVER_ERROR)는 모든 API에서 발생할 수 있으며, 각 API의 Status 표에는 INTERNAL_SERVER_ERROR만 적는다.

## 3. 엔드포인트 목록

| 카테고리 | 기능 | Method | URL | 사용자 |
| --- | --- | --- | --- | --- |
| 검색 | 습득물 검색 | GET | `/api/items` | 유저 |
| 조회 | 습득물 상세 조회 | GET | `/api/items/{atcId}` | 유저 |
| 인증 | 인증번호 발송 | POST | `/api/verifications` | 유저 |
| 인증 | 인증번호 확인 | POST | `/api/verifications/confirm` | 유저 |
| 알림 | 알림 조건 등록 | POST | `/api/alerts` | 인증 토큰 보유자 |
| 알림 | 알림 조건 조회 | GET | `/api/alerts/{alertToken}` | 관리 토큰 보유자 |
| 알림 | 알림 조건 해지 | DELETE | `/api/alerts/{alertToken}` | 관리 토큰 보유자 |

---

## 4. 습득물 검색

`GET /api/items`

물품명, 역명 중 하나 이상 입력하여 역사 내 습득물을 검색합니다.

### Request

**Query parameter**

| key | 설명 | value 타입 | 옵션 | Nullable | 예시 |
| --- | --- | --- | --- | --- | --- |
| item | 물품명 | String | 부분 검색, 최대 200자 | O | 지갑 |
| station | 역명 | String | 부분 검색, 최대 200자 | O | 마곡역 |
| page | 페이지 번호 | Integer | 기본값 1, 1 이상 | O | 1 |

- 한 페이지에 20건씩 반환한다.
- item 또는 station이 200자를 넘으면 INVALID_REQUEST로 처리한다.
- item은 띄어쓰기와 영문 대소문자를 무시하고 부분 일치로 비교한다. 공백만 입력한 값은 입력하지 않은 것으로 본다.
- 마지막 페이지를 넘는 page를 요청하면 에러가 아니라 빈 목록을 반환한다.

| 요청 예시 | 설명 |
| --- | --- |
| `/api/items?item=지갑` | 물품명만 (부분 검색, "검정 지갑"도 포함) |
| `/api/items?station=마곡` | 역명만 (부분 검색) |
| `/api/items?item=지갑&station=마곡역&page=2` | 둘 다 + 2페이지 |

### Response

| key | 설명 | value 타입 | 옵션 | Nullable | 예시 |
| --- | --- | --- | --- | --- | --- |
| items | 습득물 목록 | Array | 습득일자 최신순 | X |  |
| items[].atcId | 관리번호 | String |  | X | V0007729L09160018 |
| items[].fdPrdtNm | 물품명 | String |  | X | 검정 지갑 |
| items[].fdYmd | 습득일자 | String | yyyy-MM-dd | X | 2026-09-12 |
| items[].depPlace | 보관장소 | String |  | X | 강남역 |
| items[].fdFilePathImg | 사진 경로 | String |  | O | https://minwon24... |
| totalItems | 전체 결과 수 | Integer |  | X | 23 |
| totalPages | 전체 페이지 수 | Integer | 결과가 없으면 0 | X | 2 |
| currentPage | 현재 페이지 | Integer |  | X | 1 |
| pageSize | 한 페이지의 개수 | Integer | 20 고정 | X | 20 |

```json
{
  "items": [
    {
      "atcId": "V0007729L09160018",
      "fdPrdtNm": "검정 지갑",
      "fdYmd": "2026-09-12",
      "depPlace": "강남역",
      "fdFilePathImg": "https://minwon24.police.go.kr/..."
    }
  ],
  "totalItems": 23,
  "totalPages": 2,
  "currentPage": 1,
  "pageSize": 20
}
```

### Status

| status | code | 설명 |
| --- | --- | --- |
| 200 |  | 검색 성공. 보관 상태가 종결인 습득물은 결과에서 제외 |
| 400 | SEARCH_CONDITION_REQUIRED | item과 station이 모두 비어 있음 |
| 400 | INVALID_PAGE | page가 숫자가 아니거나 1 미만 |
| 500 | INTERNAL_SERVER_ERROR | 서버 오류 |

---

## 5. 습득물 상세 조회

`GET /api/items/{atcId}`

관리번호(atcId)를 통하여 습득물의 상세정보를 조회합니다.

### Request

**Path parameter**

`/api/items/V0007729L09160018`

| key | 설명 | value 타입 | 옵션 | Nullable | 예시 |
| --- | --- | --- | --- | --- | --- |
| atcId | 관리번호 | String |  | X | V0007729L09160018 |

### Response

| key | 설명 | value 타입 | 옵션 | Nullable | 예시 |
| --- | --- | --- | --- | --- | --- |
| atcId | 관리번호 | String |  | X | V0007729L09160018 |
| fdPrdtNm | 물품명 | String |  | X | 검정 지갑 |
| prdtClNm | 물품분류명 | String |  | O | 지갑 > 남성용 지갑 |
| clrNm | 색상명 | String |  | O | 블랙(검정) |
| fdYmd | 습득일자 | String | yyyy-MM-dd | X | 2026-09-12 |
| fdHor | 습득시간 | String |  | O | 17 |
| fdPlace | 습득장소 | String |  | O | 2호선 열차 내 |
| depPlace | 보관장소 | String |  | X | 시청유실물센터 |
| orgNm | 기관명 | String |  | O | 서울교통공사 |
| tel | 보관처 전화번호 | String |  | O | 02-1234-5678 |
| uniq | 특이사항 | String |  | O | 특이사항 : 없음 |
| fdFilePathImg | 사진 경로 | String |  | O | https://minwon24... |
| csteSteNm | 보관 상태 | String |  | X | 보관중 |
| lastCkDate | 보관 상태 마지막 확인 시각 | String | yyyy-MM-dd HH:mm:ss | X | 2026-09-26 04:30:00 |

```json
{
  "atcId": "V0007729L09160018",
  "fdPrdtNm": "검정 지갑",
  "prdtClNm": "지갑 > 남성용 지갑",
  "clrNm": "블랙(검정)",
  "fdYmd": "2026-09-12",
  "fdHor": "17",
  "fdPlace": "2호선 열차 내",
  "depPlace": "시청유실물센터",
  "orgNm": "서울교통공사",
  "tel": "02-1234-5678",
  "uniq": "특이사항 : 없음",
  "fdFilePathImg": "https://minwon24.police.go.kr/...",
  "csteSteNm": "보관중",
  "lastCkDate": "2026-09-26 04:30:00"
}
```

### Status

| status | code | 설명 |
| --- | --- | --- |
| 200 |  | 조회 성공. 종결된 습득물도 조회 성공으로 간주하며 csteSteNm이 종결로 옴 |
| 404 | ATCID_NOT_FOUND | 해당 관리번호의 습득물이 없음 |
| 500 | INTERNAL_SERVER_ERROR | 서버 오류 |

---

## 6. 인증번호 발송

`POST /api/verifications`

입력한 이메일로 6자리 인증번호를 발송합니다. 같은 이메일로는 1분에 1회만 발송할 수 있습니다.

### Request

**Body**

| key | 설명 | value 타입 | 옵션 | Nullable | 예시 |
| --- | --- | --- | --- | --- | --- |
| mAddr | 인증번호를 받을 이메일 주소 | String | 이메일 형식, 최대 254자 | X | plzhireme@gmail.com |

- 같은 이메일로 인증번호를 다시 발송하면, 이전에 발송한 인증번호는 즉시 무효가 된다.
- 같은 IP에서는 1시간에 20회까지만 발송할 수 있다. IP는 요청 값으로 받지 않고, 서버가 접속한 클라이언트의 주소를 직접 확인한다.
- 메일 발송에 실패한 요청은 이메일·IP 발송 횟수에 포함하지 않는다.
- 이메일 제한과 IP 제한에 동시에 걸리면, 대기 시간이 더 긴 IP 제한(VERIFICATION_IP_LIMIT)을 반환한다.

```json
{
  "mAddr": "plzhireme@gmail.com"
}
```

### Response

| key | 설명 | value 타입 | 옵션 | Nullable | 예시 |
| --- | --- | --- | --- | --- | --- |
| expDate | 인증번호 만료 시각 | String | yyyy-MM-dd HH:mm:ss | X | 2026-09-26 14:40:00 |

```json
{
  "expDate": "2026-09-26 14:40:00"
}
```

### Status

| status | code | 설명 |
| --- | --- | --- |
| 200 |  | 인증번호 발송 성공. 인증번호는 응답에 포함하지 않고 이메일로만 전달 |
| 400 | EMAIL_INVALID | 이메일이 비어 있거나 형식이 올바르지 않음 |
| 429 | VERIFICATION_TOO_MANY_REQUESTS | 같은 이메일로 1분 이내에 다시 요청함. `Retry-After` 헤더로 재요청 가능까지 남은 초를 함께 반환 |
| 429 | VERIFICATION_IP_LIMIT | 같은 IP에서 1시간 이내 발송 한도(20회)를 초과함. `Retry-After` 헤더로 남은 초를 함께 반환 |
| 503 | VERIFICATION_MAIL_SEND_FAILED | 메일 발송 실패. 발송한 인증번호는 저장하지 않으므로 바로 다시 시도할 수 있음 |
| 500 | INTERNAL_SERVER_ERROR | 서버 오류 |

---

## 7. 인증번호 확인

`POST /api/verifications/confirm`

이메일과 인증번호를 확인하고, 일치하면 알림 조건 등록에 사용할 인증 토큰을 발급합니다.

### Request

**Body**

| key | 설명 | value 타입 | 옵션 | Nullable | 예시 |
| --- | --- | --- | --- | --- | --- |
| mAddr | 인증번호를 받은 이메일 주소 | String | 인증번호 발송에 사용한 이메일 | X | plzhireme@gmail.com |
| verNum | 메일로 받은 인증번호 | String | 숫자 6자리 | X | 048213 |

- mAddr와 verNum은 형식을 따로 검사하지 않고, 저장된 인증 기록과 대조해 확인한다.
- 인증번호를 5회 틀리면 해당 인증번호는 무효화되며, 인증번호를 다시 발송받아야 한다.
- 인증번호를 다시 발송한 뒤 이전 인증번호를 입력하면, 가장 최근에 발송한 인증번호와 대조하므로 불일치로 처리한다(VERIFICATION_MISMATCH).

```json
{
  "mAddr": "plzhireme@gmail.com",
  "verNum": "048213"
}
```

### Response

| key | 설명 | value 타입 | 옵션 | Nullable | 예시 |
| --- | --- | --- | --- | --- | --- |
| verToken | 알림 조건 등록에 사용할 인증 토큰 | String | 1회만 사용 가능 | X | 9b2f1c7e-4a3d-4e8b-a1f0-6c5d2e8b7a91 |
| expDate | 인증 토큰 만료 시각 (발급 후 30분) | String | yyyy-MM-dd HH:mm:ss | X | 2026-09-26 15:05:00 |

```json
{
  "verToken": "9b2f1c7e-4a3d-4e8b-a1f0-6c5d2e8b7a91",
  "expDate": "2026-09-26 15:05:00"
}
```

### Status

| status | code | 설명 |
| --- | --- | --- |
| 200 |  | 인증 성공. 알림 조건 등록에 사용할 인증 토큰을 발급함 |
| 401 | VERIFICATION_NOT_FOUND | 발송된 인증번호가 없음 |
| 401 | VERIFICATION_EXPIRED | 인증번호 만료 (10분 경과) |
| 401 | VERIFICATION_USED | 이미 확인을 마친 인증번호 |
| 401 | VERIFICATION_LOCKED | 5회 틀려서 잠김 |
| 401 | VERIFICATION_MISMATCH | 인증번호 불일치 |
| 500 | INTERNAL_SERVER_ERROR | 서버 오류 |

---

## 8. 알림 조건 등록

`POST /api/alerts`

인증 토큰을 확인한 뒤 알림 조건을 등록하고, 등록 완료 메일을 발송합니다. 역과 물품명 중 하나 이상 필요합니다. 역명은 수집 시와 같은 규칙으로 정규화하며, 존재하지 않는 역이면 등록을 거부합니다.

### Request

**Body**

| key | 설명 | value 타입 | 옵션 | Nullable | 예시 |
| --- | --- | --- | --- | --- | --- |
| verToken | 인증번호 확인 API에서 받은 인증 토큰 | String | 1회만 사용 가능 | X | 9b2f1c7e-4a3d-4e8b-a1f0-6c5d2e8b7a91 |
| condStNm | 조건 역명 | String | 최대 200자 | O | 마곡 |
| condPrdtNm | 조건 물품명 | String | 최대 200자 | O | 지갑 |

- condStNm과 condPrdtNm 중 하나 이상은 필수. 공백만 입력한 값은 입력하지 않은 것으로 본다.
- condPrdtNm은 습득물 물품명과 띄어쓰기·영문 대소문자를 무시한 부분 일치로 매칭한다. 동의어는 지원하지 않는다.
- condStNm은 수집 시와 같은 규칙으로 정규화하며, 존재하지 않는 역이면 등록을 거부
- 알림을 받을 이메일은 요청으로 받지 않고, 인증 토큰에 연결된 인증 기록의 이메일을 사용한다.
- 인증 토큰은 등록에 성공하면 사용 처리되어 다시 쓸 수 없다. 등록에 실패하면 사용 처리하지 않으므로, 만료 전까지 다시 시도할 수 있다.
- 같은 이메일로 정규화된 역명과 물품명이 모두 같은 조건이 유효한 상태로 이미 있으면 등록을 거부한다.
- 관리 토큰은 이메일 소유자에게만 전달하기 위해 등록 완료 메일로만 보내며, 응답 본문과 `Location` 헤더에는 포함하지 않는다.

```json
{
  "verToken": "9b2f1c7e-4a3d-4e8b-a1f0-6c5d2e8b7a91",
  "condStNm": "마곡",
  "condPrdtNm": "지갑"
}
```

### Response

| key | 설명 | value 타입 | 옵션 | Nullable | 예시 |
| --- | --- | --- | --- | --- | --- |
| condStNm | 저장된 조건 역명 (정규화된 값) | String |  | O | 마곡역 |
| condPrdtNm | 조건 물품명 | String |  | O | 지갑 |
| expDate | 알림 조건 만료 시각 | String | yyyy-MM-dd HH:mm:ss | X | 2026-10-27 14:35:00 |

```json
{
  "condStNm": "마곡역",
  "condPrdtNm": "지갑",
  "expDate": "2026-10-27 14:35:00"
}
```

### Status

| status | code | 설명 |
| --- | --- | --- |
| 201 |  | 등록 성공. 관리 토큰을 발급하고, 등록 완료 메일(관리 링크 포함)을 발송함 |
| 400 | CONDITION_REQUIRED | 역과 물품명이 모두 비어 있음 |
| 400 | CONDITION_TOO_LONG | 최대 길이 초과 |
| 400 | STATION_NOT_FOUND | 존재하지 않는 역 |
| 401 | VER_TOKEN_INVALID | 인증 토큰이 없음, 만료, 이미 사용함 |
| 409 | CONDITION_DUPLICATE | 같은 이메일로 같은 조건이 이미 등록되어 있음 |
| 503 | ALERT_MAIL_SEND_FAILED | 등록 완료 메일 발송 실패. 등록은 취소되며 다시 시도할 수 있음 |
| 500 | INTERNAL_SERVER_ERROR | 서버 오류 |

---

## 9. 알림 조건 조회

`GET /api/alerts/{alertToken}`

메일 링크의 관리 토큰으로 등록한 알림 조건을 조회합니다.

### Request

**Path parameter**

`/api/alerts/123e4567-e89b-12d3-a456-556642440000`

| key | 설명 | value 타입 | 옵션 | Nullable | 예시 |
| --- | --- | --- | --- | --- | --- |
| alertToken | 관리 토큰 (메일 링크에 포함) | String |  | X | 123e4567-e89b-12d3-a456-556642440000 |

### Response

| key | 설명 | value 타입 | 옵션 | Nullable | 예시 |
| --- | --- | --- | --- | --- | --- |
| condStNm | 조건 역명 (정규화된 값) | String |  | O | 마곡역 |
| condPrdtNm | 조건 물품명 | String |  | O | 지갑 |
| expDate | 알림 조건 만료 시각 | String | yyyy-MM-dd HH:mm:ss | X | 2026-10-27 14:35:00 |

```json
{
  "condStNm": "마곡역",
  "condPrdtNm": "지갑",
  "expDate": "2026-10-27 14:35:00"
}
```

### Status

| status | code | 설명 |
| --- | --- | --- |
| 200 |  | 조회 성공 |
| 404 | ALERT_NOT_FOUND | 해당 토큰의 알림 조건이 없음 (잘못된 링크, 해지됨, 만료됨) |
| 500 | INTERNAL_SERVER_ERROR | 서버 오류 |

---

## 10. 알림 조건 해지

`DELETE /api/alerts/{alertToken}`

알림 조건과 관련 기록을 삭제합니다.

### Request

**Path parameter**

`/api/alerts/123e4567-e89b-12d3-a456-556642440000`

| key | 설명 | value 타입 | 옵션 | Nullable | 예시 |
| --- | --- | --- | --- | --- | --- |
| alertToken | 관리 토큰 (메일 링크에 포함) | String |  | X | 123e4567-e89b-12d3-a456-556642440000 |

### Response

응답 본문 없음 (204 No Content)

### Status

| status | code | 설명 |
| --- | --- | --- |
| 204 |  | 해지 성공. 알림 조건과 관련 매칭 기록, 메일 발송 기록을 모두 삭제 |
| 404 | ALERT_NOT_FOUND | 해당 토큰의 알림 조건이 없음 (잘못된 링크, 해지됨, 만료됨) |
| 500 | INTERNAL_SERVER_ERROR | 서버 오류 |