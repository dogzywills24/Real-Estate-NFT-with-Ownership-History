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

(define-constant ERR-INVALID-MAINTENANCE (err u111))

(define-constant ERR-NOT-LEASED (err u112))
(define-constant ERR-ALREADY-LEASED (err u113))
(define-constant ERR-INVALID-LEASE-TERMS (err u114))
(define-constant ERR-LEASE-EXPIRED (err u115))
(define-constant ERR-PAYMENT-AMOUNT-MISMATCH (err u116))

(define-constant ERR-OFFER-NOT-FOUND (err u117))
(define-constant ERR-INVALID-OFFER (err u118))

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


(define-map property-maintenance
  { token-id: uint, maintenance-id: uint }
  {
    owner: principal,
    maintenance-type: (string-ascii 50),
    description: (string-ascii 200),
    cost: uint,
    contractor: (optional (string-ascii 100)),
    date-completed: uint,
    timestamp: uint
  }
)

(define-map maintenance-count
  { token-id: uint }
  { count: uint }
)

(define-read-only (get-maintenance-count (token-id uint))
  (default-to u0 (get count (map-get? maintenance-count { token-id: token-id })))
)

(define-read-only (get-property-maintenance (token-id uint) (maintenance-id uint))
  (map-get? property-maintenance { token-id: token-id, maintenance-id: maintenance-id })
)

(define-read-only (get-latest-maintenance (token-id uint))
  (let ((count (get-maintenance-count token-id)))
    (if (> count u0)
      (get-property-maintenance token-id (- count u1))
      none
    )
  )
)

(define-read-only (get-total-maintenance-cost (token-id uint))
  (let ((count (get-maintenance-count token-id)))
    (fold + (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9) u0)
  )
)

(define-public (record-maintenance 
  (token-id uint)
  (maintenance-type (string-ascii 50))
  (description (string-ascii 200))
  (cost uint)
  (contractor (optional (string-ascii 100)))
)
  (let ((current-count (get-maintenance-count token-id))
        (owner (nft-get-owner? real-estate-nft token-id)))
    (begin
      (asserts! (is-some owner) ERR-PROPERTY-NOT-FOUND)
      (asserts! (is-eq (some tx-sender) owner) ERR-NOT-TOKEN-OWNER)
      (asserts! (> (len maintenance-type) u0) ERR-INVALID-MAINTENANCE)
      (asserts! (> (len description) u0) ERR-INVALID-MAINTENANCE)
      (map-set property-maintenance
        { token-id: token-id, maintenance-id: current-count }
        {
          owner: tx-sender,
          maintenance-type: maintenance-type,
          description: description,
          cost: cost,
          contractor: contractor,
          date-completed: stacks-block-height,
          timestamp: stacks-block-height
        }
      )
      (map-set maintenance-count { token-id: token-id } { count: (+ current-count u1) })
      (ok current-count)
    )
  )
)


(define-map property-leases
  { token-id: uint }
  {
    landlord: principal,
    tenant: principal,
    monthly-rent: uint,
    deposit: uint,
    start-block: uint,
    end-block: uint,
    active: bool
  }
)

(define-map lease-payments
  { token-id: uint, payment-id: uint }
  {
    tenant: principal,
    amount: uint,
    payment-block: uint,
    period-start: uint,
    period-end: uint
  }
)

(define-map payment-count
  { token-id: uint }
  { count: uint }
)

(define-read-only (get-active-lease (token-id uint))
  (map-get? property-leases { token-id: token-id })
)

(define-read-only (get-payment-count (token-id uint))
  (default-to u0 (get count (map-get? payment-count { token-id: token-id })))
)

(define-read-only (get-lease-payment (token-id uint) (payment-id uint))
  (map-get? lease-payments { token-id: token-id, payment-id: payment-id })
)

(define-public (create-lease (token-id uint) (tenant principal) (monthly-rent uint) (deposit uint) (duration-blocks uint))
  (let ((owner (nft-get-owner? real-estate-nft token-id)))
    (begin
      (asserts! (is-eq (some tx-sender) owner) ERR-NOT-TOKEN-OWNER)
      (asserts! (is-none (get-active-lease token-id)) ERR-ALREADY-LEASED)
      (asserts! (> monthly-rent u0) ERR-INVALID-LEASE-TERMS)
      (asserts! (> duration-blocks u0) ERR-INVALID-LEASE-TERMS)
      (try! (stx-transfer? deposit tenant tx-sender))
      (map-set property-leases
        { token-id: token-id }
        {
          landlord: tx-sender,
          tenant: tenant,
          monthly-rent: monthly-rent,
          deposit: deposit,
          start-block: stacks-block-height,
          end-block: (+ stacks-block-height duration-blocks),
          active: true
        }
      )
      (ok true)
    )
  )
)

(define-public (pay-rent (token-id uint) (period-start uint) (period-end uint))
  (let ((lease (get-active-lease token-id)))
    (begin
      (asserts! (is-some lease) ERR-NOT-LEASED)
      (let ((lease-data (unwrap-panic lease))
            (current-count (get-payment-count token-id)))
        (begin
          (asserts! (get active lease-data) ERR-NOT-LEASED)
          (asserts! (<= stacks-block-height (get end-block lease-data)) ERR-LEASE-EXPIRED)
          (asserts! (is-eq tx-sender (get tenant lease-data)) ERR-NOT-TOKEN-OWNER)
          (try! (stx-transfer? (get monthly-rent lease-data) tx-sender (get landlord lease-data)))
          (map-set lease-payments
            { token-id: token-id, payment-id: current-count }
            {
              tenant: tx-sender,
              amount: (get monthly-rent lease-data),
              payment-block: stacks-block-height,
              period-start: period-start,
              period-end: period-end
            }
          )
          (map-set payment-count { token-id: token-id } { count: (+ current-count u1) })
          (ok true)
        )
      )
    )
  )
)

(define-public (end-lease (token-id uint) (refund-deposit bool))
  (let ((lease (get-active-lease token-id)))
    (begin
      (asserts! (is-some lease) ERR-NOT-LEASED)
      (let ((lease-data (unwrap-panic lease)))
        (begin
          (asserts! (is-eq tx-sender (get landlord lease-data)) ERR-NOT-TOKEN-OWNER)
          (if refund-deposit
            (try! (stx-transfer? (get deposit lease-data) tx-sender (get tenant lease-data)))
            true
          )
          (map-set property-leases
            { token-id: token-id }
            (merge lease-data { active: false })
          )
          (ok true)
        )
      )
    )
  )
)

(define-map property-offers
  { token-id: uint, offer-id: uint }
  {
    buyer: principal,
    offered-price: uint,
    offer-block: uint,
    expires-at: uint,
    active: bool
  }
)

(define-map offer-count
  { token-id: uint }
  { count: uint }
)

(define-read-only (get-offer-count (token-id uint))
  (default-to u0 (get count (map-get? offer-count { token-id: token-id })))
)

(define-read-only (get-property-offer (token-id uint) (offer-id uint))
  (map-get? property-offers { token-id: token-id, offer-id: offer-id })
)

(define-public (make-offer (token-id uint) (offered-price uint) (duration-blocks uint))
  (let ((owner (nft-get-owner? real-estate-nft token-id))
        (current-count (get-offer-count token-id)))
    (begin
      (asserts! (is-some owner) ERR-PROPERTY-NOT-FOUND)
      (asserts! (not (is-eq (some tx-sender) owner)) ERR-NOT-TOKEN-OWNER)
      (asserts! (> offered-price u0) ERR-INVALID-OFFER)
      (asserts! (> duration-blocks u0) ERR-INVALID-OFFER)
      (map-set property-offers
        { token-id: token-id, offer-id: current-count }
        {
          buyer: tx-sender,
          offered-price: offered-price,
          offer-block: stacks-block-height,
          expires-at: (+ stacks-block-height duration-blocks),
          active: true
        }
      )
      (map-set offer-count { token-id: token-id } { count: (+ current-count u1) })
      (ok current-count)
    )
  )
)

(define-public (accept-offer (token-id uint) (offer-id uint))
  (let ((offer (get-property-offer token-id offer-id))
        (owner (nft-get-owner? real-estate-nft token-id)))
    (begin
      (asserts! (is-some offer) ERR-OFFER-NOT-FOUND)
      (asserts! (is-eq (some tx-sender) owner) ERR-NOT-TOKEN-OWNER)
      (let ((offer-data (unwrap-panic offer)))
        (begin
          (asserts! (get active offer-data) ERR-OFFER-NOT-FOUND)
          (asserts! (<= stacks-block-height (get expires-at offer-data)) ERR-OFFER-NOT-FOUND)
          (try! (stx-transfer? (get offered-price offer-data) (get buyer offer-data) tx-sender))
          (try! (nft-transfer? real-estate-nft token-id tx-sender (get buyer offer-data)))
          (unwrap-panic (record-transfer token-id (some tx-sender) (get buyer offer-data) (get offered-price offer-data)))
          (map-set property-offers
            { token-id: token-id, offer-id: offer-id }
            (merge offer-data { active: false })
          )
          (ok true)
        )
      )
    )
  )
)

(define-public (cancel-offer (token-id uint) (offer-id uint))
  (let ((offer (get-property-offer token-id offer-id)))
    (begin
      (asserts! (is-some offer) ERR-OFFER-NOT-FOUND)
      (let ((offer-data (unwrap-panic offer)))
        (begin
          (asserts! (is-eq tx-sender (get buyer offer-data)) ERR-NOT-TOKEN-OWNER)
          (asserts! (get active offer-data) ERR-OFFER-NOT-FOUND)
          (map-set property-offers
            { token-id: token-id, offer-id: offer-id }
            (merge offer-data { active: false })
          )
          (ok true)
        )
      )
    )
  )
)