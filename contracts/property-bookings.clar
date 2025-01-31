;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-dates (err u101))
(define-constant err-already-booked (err u102))
(define-constant err-not-owner (err u103))

;; Data Variables
(define-data-var min-stay uint u2)
(define-data-var max-stay uint u14)

;; Data Maps
(define-map bookings
    { booking-id: uint }
    {
        owner: principal,
        check-in: uint,
        check-out: uint,
        status: (string-ascii 20)
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

;; Public Functions
(define-public (book-property (check-in uint) (check-out uint))
    (let
        (
            (booking-id (+ (var-get booking-nonce) u1))
            (stay-duration (- check-out check-in))
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
                status: "confirmed"
            }
        )
        
        (var-set booking-nonce booking-id)
        (ok booking-id)
    )
)

(define-public (cancel-booking (booking-id uint))
    (let (
        (booking (unwrap! (map-get? bookings { booking-id: booking-id }) err-invalid-dates))
    )
        (asserts! (is-eq (get owner booking) tx-sender) err-not-owner)
        (map-set bookings
            { booking-id: booking-id }
            (merge booking { status: "cancelled" })
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
