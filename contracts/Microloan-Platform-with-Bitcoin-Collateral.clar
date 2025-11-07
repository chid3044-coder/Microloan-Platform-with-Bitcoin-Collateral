(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-insufficient-collateral (err u103))
(define-constant err-loan-not-active (err u104))
(define-constant err-unauthorized (err u105))
(define-constant err-loan-not-defaulted (err u106))
(define-constant err-already-repaid (err u107))
(define-constant err-invalid-amount (err u108))
(define-constant err-invalid-duration (err u109))
(define-constant err-collateral-ratio (err u110))

(define-constant min-collateral-ratio u150)
(define-constant liquidation-threshold u120)
(define-constant blocks-per-day u144)

(define-data-var loan-id-nonce uint u0)
(define-data-var platform-fee-rate uint u50)
(define-data-var total-fees-collected uint u0)

(define-map loans
  uint
  {
    borrower: principal,
    lender: (optional principal),
    loan-amount: uint,
    collateral-amount: uint,
    interest-rate: uint,
    duration-blocks: uint,
    start-block: uint,
    repayment-amount: uint,
    status: (string-ascii 20),
    funded-block: (optional uint)
  }
)

(define-map user-loan-count principal uint)

(define-read-only (get-loan (loan-id uint))
  (map-get? loans loan-id)
)

(define-read-only (get-user-loan-count (user principal))
  (default-to u0 (map-get? user-loan-count user))
)

(define-read-only (get-platform-fee-rate)
  (var-get platform-fee-rate)
)

(define-read-only (get-total-fees-collected)
  (var-get total-fees-collected)
)

(define-read-only (calculate-repayment-amount (loan-amount uint) (interest-rate uint) (duration-blocks uint))
  (let
    (
      (interest (/ (* loan-amount interest-rate) u10000))
      (total-repayment (+ loan-amount interest))
    )
    (ok total-repayment)
  )
)

(define-read-only (is-loan-defaulted (loan-id uint))
  (match (map-get? loans loan-id)
    loan-data
      (match (get funded-block loan-data)
        funded-blk
          (let
            (
              (current-block stacks-block-height)
              (expiry-block (+ funded-blk (get duration-blocks loan-data)))
            )
            (and
              (is-eq (get status loan-data) "active")
              (> current-block expiry-block)
            )
          )
        false
      )
    false
  )
)

(define-read-only (get-collateral-ratio (loan-amount uint) (collateral-amount uint))
  (if (is-eq loan-amount u0)
    u0
    (/ (* collateral-amount u100) loan-amount)
  )
)

(define-public (create-loan-request (loan-amount uint) (collateral-amount uint) (interest-rate uint) (duration-blocks uint))
  (let
    (
      (new-loan-id (+ (var-get loan-id-nonce) u1))
      (collateral-ratio (get-collateral-ratio loan-amount collateral-amount))
      (repayment-amt (unwrap! (calculate-repayment-amount loan-amount interest-rate duration-blocks) err-invalid-amount))
    )
    (asserts! (> loan-amount u0) err-invalid-amount)
    (asserts! (> collateral-amount u0) err-invalid-amount)
    (asserts! (> duration-blocks u0) err-invalid-duration)
    (asserts! (>= collateral-ratio min-collateral-ratio) err-collateral-ratio)
    (try! (stx-transfer? collateral-amount tx-sender (as-contract tx-sender)))
    (map-set loans new-loan-id {
      borrower: tx-sender,
      lender: none,
      loan-amount: loan-amount,
      collateral-amount: collateral-amount,
      interest-rate: interest-rate,
      duration-blocks: duration-blocks,
      start-block: stacks-block-height,
      repayment-amount: repayment-amt,
      status: "pending",
      funded-block: none
    })
    (map-set user-loan-count tx-sender (+ (get-user-loan-count tx-sender) u1))
    (var-set loan-id-nonce new-loan-id)
    (ok new-loan-id)
  )
)

(define-public (fund-loan (loan-id uint))
  (let
    (
      (loan-data (unwrap! (map-get? loans loan-id) err-not-found))
    )
    (asserts! (is-eq (get status loan-data) "pending") err-loan-not-active)
    (asserts! (is-none (get lender loan-data)) err-already-exists)
    (try! (stx-transfer? (get loan-amount loan-data) tx-sender (get borrower loan-data)))
    (map-set loans loan-id (merge loan-data {
      lender: (some tx-sender),
      status: "active",
      funded-block: (some stacks-block-height)
    }))
    (ok true)
  )
)

(define-public (repay-loan (loan-id uint))
  (let
    (
      (loan-data (unwrap! (map-get? loans loan-id) err-not-found))
      (repayment-amt (get repayment-amount loan-data))
      (platform-fee (/ (* repayment-amt (var-get platform-fee-rate)) u10000))
      (lender-amount (- repayment-amt platform-fee))
    )
    (asserts! (is-eq (get borrower loan-data) tx-sender) err-unauthorized)
    (asserts! (is-eq (get status loan-data) "active") err-loan-not-active)
    (asserts! (is-some (get lender loan-data)) err-not-found)
    (try! (stx-transfer? lender-amount tx-sender (unwrap-panic (get lender loan-data))))
    (try! (stx-transfer? platform-fee tx-sender contract-owner))
    (try! (as-contract (stx-transfer? (get collateral-amount loan-data) tx-sender (get borrower loan-data))))
    (map-set loans loan-id (merge loan-data {
      status: "repaid"
    }))
    (var-set total-fees-collected (+ (var-get total-fees-collected) platform-fee))
    (ok true)
  )
)

(define-public (liquidate-loan (loan-id uint))
  (let
    (
      (loan-data (unwrap! (map-get? loans loan-id) err-not-found))
    )
    (asserts! (is-eq (get status loan-data) "active") err-loan-not-active)
    (asserts! (is-some (get lender loan-data)) err-not-found)
    (asserts! (is-loan-defaulted loan-id) err-loan-not-defaulted)
    (try! (as-contract (stx-transfer? (get collateral-amount loan-data) tx-sender (unwrap-panic (get lender loan-data)))))
    (map-set loans loan-id (merge loan-data {
      status: "liquidated"
    }))
    (ok true)
  )
)

(define-public (cancel-loan-request (loan-id uint))
  (let
    (
      (loan-data (unwrap! (map-get? loans loan-id) err-not-found))
    )
    (asserts! (is-eq (get borrower loan-data) tx-sender) err-unauthorized)
    (asserts! (is-eq (get status loan-data) "pending") err-loan-not-active)
    (asserts! (is-none (get lender loan-data)) err-already-exists)
    (try! (as-contract (stx-transfer? (get collateral-amount loan-data) tx-sender (get borrower loan-data))))
    (map-set loans loan-id (merge loan-data {
      status: "cancelled"
    }))
    (ok true)
  )
)

(define-public (set-platform-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-rate u1000) err-invalid-amount)
    (var-set platform-fee-rate new-rate)
    (ok true)
  )
)

(define-public (withdraw-fees)
  (let
    (
      (total-fees (var-get total-fees-collected))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> total-fees u0) err-invalid-amount)
    (var-set total-fees-collected u0)
    (ok total-fees)
  )
)

