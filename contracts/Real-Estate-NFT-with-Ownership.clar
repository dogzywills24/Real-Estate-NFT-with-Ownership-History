(define-non-fungible-token real-estate-nft uint)

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-TOKEN-OWNER (err u101))
(define-constant ERR-LISTING-NOT-FOUND (err u102))
(define-constant ERR-INSUFFICIENT-FUNDS (err u103))
(define-constant ERR-PROPERTY-NOT-FOUND (err u104))
(define-constant ERR-ALREADY-LISTED (err u105))
(define-constant ERR-NOT-LISTED (err u106))

(define-constant ERR-NOT-APPRAISER (err u107))
(define-constant ERR-INVALID-APPRAISAL (err u108))

(define-data-var appraiser-registry (list 50 principal) (list))

(define-data-var last-token-id uint u0)

(define-map property-data
  { token-id: uint } 
  {
    address: (string-ascii 100),
    property-type: (string-ascii 50),
    bedrooms: uint,
    bathrooms: uint,
    square-feet: uint,
    year-built: uint,
    created-at: uint
  }
)

(define-map ownership-history
  { token-id: uint, transfer-id: uint }
  {
    from: (optional principal),
    to: principal,
    price: uint,
    timestamp: uint,
    transaction-hash: (buff 32)
  }
)

(define-map transfer-count
  { token-id: uint }
  { count: uint }
)

(define-map property-listings
  { token-id: uint }
  {
    seller: principal,
    price: uint,
    listed-at: uint,
    active: bool
  }
)

(define-read-only (get-last-token-id)
  (var-get last-token-id)
)

(define-read-only (get-property-data (token-id uint))
  (map-get? property-data { token-id: token-id })
)

(define-read-only (get-ownership-history (token-id uint) (transfer-id uint))
  (map-get? ownership-history { token-id: token-id, transfer-id: transfer-id })
)

(define-read-only (get-transfer-count (token-id uint))
  (default-to u0 (get count (map-get? transfer-count { token-id: token-id })))
)

(define-read-only (get-property-listing (token-id uint))
  (map-get? property-listings { token-id: token-id })
)

(define-read-only (get-owner (token-id uint))
  (nft-get-owner? real-estate-nft token-id)
)

(define-private (record-transfer (token-id uint) (from (optional principal)) (to principal) (price uint))
  (let ((current-count (get-transfer-count token-id)))
    (begin
      (map-set ownership-history 
        { token-id: token-id, transfer-id: current-count }
        { 
          from: from,
          to: to,
          price: price,
          timestamp: stacks-block-height,
          transaction-hash: 0x0000000000000000000000000000000000000000000000000000000000000000
        }
      )
      (begin
        (map-set transfer-count { token-id: token-id } { count: (+ current-count u1) })
        (ok true)
      )
    )
  )
) 

(define-public (mint-property 
  (recipient principal)
  (address (string-ascii 100))
  (property-type (string-ascii 50))
  (bedrooms uint)
  (bathrooms uint) 
  (square-feet uint)
  (year-built uint)
)
  (let ((token-id (+ (var-get last-token-id) u1)))
    (begin
      (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
      (try! (nft-mint? real-estate-nft token-id recipient))
      (begin
        (map-set property-data
          { token-id: token-id }
          {
            address: address,
            property-type: property-type,
            bedrooms: bedrooms,
            bathrooms: bathrooms,
            square-feet: square-feet,
            year-built: year-built,
            created-at: stacks-block-height
          }
        )
        (unwrap-panic (record-transfer token-id none recipient u0))
        (begin
          (var-set last-token-id token-id)
          (ok token-id)
        )
      )
    )
  )
)

(define-public (transfer-property (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq (some sender) (nft-get-owner? real-estate-nft token-id)) ERR-NOT-TOKEN-OWNER)
    (try! (nft-transfer? real-estate-nft token-id sender recipient))
    (unwrap-panic (record-transfer token-id (some sender) recipient u0))
    (ok true)
  )
)

(define-public (list-property (token-id uint) (price uint))
  (let ((owner (nft-get-owner? real-estate-nft token-id)))
    (begin
      (asserts! (is-eq (some tx-sender) owner) ERR-NOT-TOKEN-OWNER)
      (asserts! (is-none (map-get? property-listings { token-id: token-id })) ERR-ALREADY-LISTED)
      (map-set property-listings
        { token-id: token-id }
        {
          seller: tx-sender,
          price: price,
          listed-at: stacks-block-height,
          active: true
        }
      )
      (ok true)
    )
  )
)

(define-public (unlist-property (token-id uint))
  (let ((listing (map-get? property-listings { token-id: token-id })))
    (begin
      (asserts! (is-some listing) ERR-LISTING-NOT-FOUND)
      (asserts! (is-eq tx-sender (get seller (unwrap-panic listing))) ERR-NOT-TOKEN-OWNER)
      (map-delete property-listings { token-id: token-id })
      (ok true)
    )
  )
)

(define-public (buy-property (token-id uint))
  (let ((listing (map-get? property-listings { token-id: token-id })))
    (begin
      (asserts! (is-some listing) ERR-LISTING-NOT-FOUND)
      (let ((listing-data (unwrap-panic listing)))
        (begin
          (asserts! (get active listing-data) ERR-NOT-LISTED)
          (try! (stx-transfer? (get price listing-data) tx-sender (get seller listing-data)))
          (try! (nft-transfer? real-estate-nft token-id (get seller listing-data) tx-sender))
          (unwrap-panic (record-transfer token-id (some (get seller listing-data)) tx-sender (get price listing-data)))
          (map-delete property-listings { token-id: token-id })
          (ok true)
        )
      )
    )
  )
)

(define-read-only (get-property-history (token-id uint))
  (let ((count (get-transfer-count token-id)))
    (list 
      (get-ownership-history token-id u0)
      (get-ownership-history token-id u1)
      (get-ownership-history token-id u2)
      (get-ownership-history token-id u3)
      (get-ownership-history token-id u4)
      (get-ownership-history token-id u5)
      (get-ownership-history token-id u6)
      (get-ownership-history token-id u7)
      (get-ownership-history token-id u8)
      (get-ownership-history token-id u9))
  )
) 

(define-map property-appraisals
  { token-id: uint, appraisal-id: uint }
  {
    appraiser: principal,
    appraised-value: uint,
    appraisal-date: uint,
    notes: (string-ascii 200)
  }
)

(define-map appraisal-count
  { token-id: uint }
  { count: uint }
)

(define-read-only (is-registered-appraiser (appraiser principal))
  (is-some (index-of (var-get appraiser-registry) appraiser))
)

(define-read-only (get-appraisal-count (token-id uint))
  (default-to u0 (get count (map-get? appraisal-count { token-id: token-id })))
)

(define-read-only (get-property-appraisal (token-id uint) (appraisal-id uint))
  (map-get? property-appraisals { token-id: token-id, appraisal-id: appraisal-id })
)

(define-read-only (get-latest-appraisal (token-id uint))
  (let ((count (get-appraisal-count token-id)))
    (if (> count u0)
      (get-property-appraisal token-id (- count u1))
      none
    )
  )
)

(define-public (register-appraiser (appraiser principal))
  (let ((current-list (var-get appraiser-registry)))
    (begin
      (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
      (asserts! (not (is-registered-appraiser appraiser)) (err u109))
      (asserts! (< (len current-list) u50) (err u110))
      (var-set appraiser-registry (unwrap-panic (as-max-len? (append current-list appraiser) u50)))
      (ok true)
    )
  )
)

(define-public (submit-appraisal (token-id uint) (appraised-value uint) (notes (string-ascii 200)))
  (let ((current-count (get-appraisal-count token-id))
        (property-exists (is-some (get-property-data token-id))))
    (begin
      (asserts! property-exists ERR-PROPERTY-NOT-FOUND)
      (asserts! (is-registered-appraiser tx-sender) ERR-NOT-APPRAISER)
      (asserts! (> appraised-value u0) ERR-INVALID-APPRAISAL)
      (map-set property-appraisals
        { token-id: token-id, appraisal-id: current-count }
        {
          appraiser: tx-sender,
          appraised-value: appraised-value,
          appraisal-date: stacks-block-height,
          notes: notes
        }
      )
      (map-set appraisal-count { token-id: token-id } { count: (+ current-count u1) })
      (ok current-count)
    )
  )
)