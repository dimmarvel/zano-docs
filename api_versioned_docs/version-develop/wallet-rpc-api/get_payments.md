Gets list of incoming transfers by a given payment ID

URL: ```http:://127.0.0.1:11211/json_rpc```
### Request: 
```json
{
  "id": 0,
  "jsonrpc": "2.0",
  "method": "get_payments",
  "params": {
    "allow_locked_transactions": false,
    "payment_id": "1dfe5a88ff9effb3"
  }
}
```
### Request description: 
```
    "allow_locked_transactions": Says to wallet if locked transfers should be included or not (false is strongly recomennded)
    "payment_id": Hex-encoded payment ID that is used to identify transfers

```
### Response: 
```json
{
  "id": 0,
  "jsonrpc": "2.0",
  "result": {
    "payments": [{
      "amount": 100000000000,
      "block_height": 12321,
      "payment_id": "1dfe5a88ff9effb3",
      "payment_subtransfers": [{
        "amount": 8000,
        "asset_id": "f74bb56a5b4fa562e679ccaadd697463498a66de4f1760b2cd40f11c3a00a7a8"
      }],
      "tx_hash": "01220e8304d46b940a86e383d55ca5887b34f158a7365bbcdd17c5a305814a93",
      "unlock_time": 0
    }]
  }
}
```
### Response description: 
```
    "payments": Array of payments that connected to given payment_id
      "amount": Amount of native coins transfered (native coins are always accounted in this field)
      "block_height": Block height that holds transaction
      "payment_id": Hex-encoded payment ID that related to this payment
      "payment_subtransfers": List of subtransfers that this payment has (only for assets being transferred)
        "amount": Amount of the asset transferred.
        "asset_id": Asset ID of the corresponding subtransfer.
      "tx_hash": Transaction ID that is holding this payment
      "unlock_time": Timestamp/blocknumber after which this money would become availabe, recommended don't count transfers that has this field not 0

```
<sub>Auto-doc built with: 2.2.1.506[16e457b-develop]</sub>