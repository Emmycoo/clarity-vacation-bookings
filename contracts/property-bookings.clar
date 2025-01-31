;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-dates (err u101)) 
(define-constant err-already-booked (err u102))
(define-constant err-not-owner (err u103))
(define-constant err-insufficient-funds (err u104))
(define-constant err-already-paid (err u105))

;; Data Variables
(define-data-var min-stay uint u2)
(define-data-var max-stay uint u14)
(define-data-var nightly-rate uint u100) ;; In STX
(define-data-var cancellation-fee-pct uint u20) ;; 20% fee

;; Data Maps
(define-map bookings
    { booking-id: uint }
    {
        owner: principal,
        check-in: uint, 
        check-out: uint,
        status: (string-ascii 20),
        total-amount: uint,
        amount-paid: uint
    }
)

(define-map booking-dates
    { date: uint }
    { booking-id: uint }
)

(define-data-var booking-nonce uint u0)

;; Private Functions
(define-private (is-date-available (date uint) (end-date uint))
    (and
        (>= date block-height)
        (is-none (map-get? booking-dates { date: date }))
        (<= date end-date)
    )
)

(define-private (calculate-total-amount (nights uint))
    (* nights (var-get nightly-rate))
)

;; Public Functions
(define-public (book-property (check-in uint) (check-out uint))
    (let
        (
            (booking-id (+ (var-get booking-nonce) u1))
            (stay-duration (- check-out check-in))
            (total-amount (calculate-total-amount stay-duration))
        )
        (asserts! (>= check-in block-height) err-invalid-dates)
        (asserts! (>= stay-duration (var-get min-stay)) err-invalid-dates)
        (asserts! (<= stay-duration (var-get max-stay)) err-invalid-dates)
        (asserts! (is-date-available check-in check-out) err-already-booked)
        
        (map-set bookings
            { booking-id: booking-id }
            {
                owner: tx-sender,
                check-in: check-in,
                check-out: check-out,
                status: "pending",
                total-amount: total-amount,
                amount-paid: u0
            }
        )
        
        (var-set booking-nonce booking-id)
        (ok booking-id)
    )
)

(define-public (pay-booking (booking-id uint))
    (let (
        (booking (unwrap! (map-get? bookings { booking-id: booking-id }) err-invalid-dates))
        (total-amount (get total-amount booking))
    )
        (asserts! (is-eq (get owner booking) tx-sender) err-not-owner)
        (asserts! (is-eq (get amount-paid booking) u0) err-already-paid)
        
        (try! (stx-transfer? total-amount tx-sender contract-owner))
        
        (map-set bookings
            { booking-id: booking-id }
            (merge booking {
                status: "confirmed",
                amount-paid: total-amount
            })
        )
        (ok true)
    )
)

(define-public (cancel-booking (booking-id uint))
    (let (
        (booking (unwrap! (map-get? bookings { booking-id: booking-id }) err-invalid-dates))
        (amount-paid (get amount-paid booking))
        (refund-amount (/ (* amount-paid (- u100 (var-get cancellation-fee-pct))) u100))
    )
        (asserts! (is-eq (get owner booking) tx-sender) err-not-owner)
        
        ;; Process refund if payment was made
        (if (> amount-paid u0)
            (try! (stx-transfer? refund-amount contract-owner tx-sender))
            true
        )
        
        (map-set bookings
            { booking-id: booking-id }
            (merge booking { 
                status: "cancelled",
                amount-paid: u0
            })
        )
        (ok true)
    )
)

(define-read-only (get-booking (booking-id uint))
    (map-get? bookings { booking-id: booking-id })
)

(define-public (set-min-stay (days uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set min-stay days)
        (ok true)
    )
)

(define-public (set-max-stay (days uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set max-stay days)
        (ok true)
    )
)

(define-public (set-nightly-rate (rate uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set nightly-rate rate)
        (ok true)
    )
)

(define-public (set-cancellation-fee (fee-pct uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= fee-pct u100) err-invalid-dates)
        (var-set cancellation-fee-pct fee-pct)
        (ok true)
    )
)
