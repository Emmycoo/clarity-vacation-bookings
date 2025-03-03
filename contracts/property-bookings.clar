;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-dates (err u101)) 
(define-constant err-already-booked (err u102))
(define-constant err-not-owner (err u103))
(define-constant err-insufficient-funds (err u104))
(define-constant err-already-paid (err u105))
(define-constant err-invalid-deposit (err u106))

;; Booking Status Enumeration
(define-constant STATUS-PENDING u1)
(define-constant STATUS-CONFIRMED u2)
(define-constant STATUS-CANCELLED u3)

;; Data Variables
(define-data-var min-stay uint u2)
(define-data-var max-stay uint u14)
(define-data-var nightly-rate uint u100)
(define-data-var cancellation-fee-pct uint u20)
(define-data-var min-deposit-pct uint u30)

;; Events
(define-data-var last-event-id uint u0)
(define-map events 
    { event-id: uint }
    {
        event-type: (string-ascii 20),
        booking-id: uint,
        timestamp: uint
    }
)

;; Data Maps
(define-map bookings
    { booking-id: uint }
    {
        owner: principal,
        check-in: uint, 
        check-out: uint,
        status: uint,
        total-amount: uint,
        amount-paid: uint,
        deposit-paid: uint
    }
)

(define-map booking-dates
    { date: uint }
    { booking-id: uint }
)

(define-data-var booking-nonce uint u0)

;; Private Functions
(define-private (validate-dates (check-in uint) (check-out uint))
    (and
        (> check-out check-in)
        (>= check-in block-height)
        (<= (- check-out check-in) (var-get max-stay))
        (>= (- check-out check-in) (var-get min-stay))
    )
)

(define-private (is-date-available (date uint))
    (is-none (map-get? booking-dates { date: date }))
)

(define-private (is-date-range-available-iter (current-date uint) (end-date uint))
    (and
        (is-date-available current-date)
        (if (>= current-date end-date)
            true
            (is-date-range-available-iter (+ current-date u1) end-date)
        )
    )
)

(define-private (is-date-range-available (check-in uint) (check-out uint))
    (is-date-range-available-iter check-in (- check-out u1))
)

(define-private (mark-dates-booked-iter (current-date uint) (end-date uint) (booking-id uint))
    (begin
        (map-set booking-dates { date: current-date } { booking-id: booking-id })
        (if (>= current-date end-date)
            true
            (mark-dates-booked-iter (+ current-date u1) end-date booking-id)
        )
    )
)

(define-private (mark-dates-booked (check-in uint) (check-out uint) (booking-id uint))
    (mark-dates-booked-iter check-in (- check-out u1) booking-id)
)

(define-private (emit-event (event-type (string-ascii 20)) (booking-id uint))
    (let ((event-id (+ (var-get last-event-id) u1)))
        (begin
            (map-set events
                { event-id: event-id }
                {
                    event-type: event-type,
                    booking-id: booking-id,
                    timestamp: block-height
                }
            )
            (var-set last-event-id event-id)
            event-id
        )
    )
)

;; Public Getter Functions
(define-read-only (get-booking (booking-id uint))
    (map-get? bookings { booking-id: booking-id })
)

(define-read-only (get-date-booking (date uint))
    (map-get? booking-dates { date: date })
)

;; Configuration Functions
(define-public (update-nightly-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set nightly-rate new-rate)
        (ok true)
    )
)

;; Original booking function remains the same
(define-public (book-property (check-in uint) (check-out uint))
    (let
        (
            (booking-id (+ (var-get booking-nonce) u1))
            (stay-duration (- check-out check-in))
            (total-amount (calculate-total-amount stay-duration))
        )
        (asserts! (validate-dates check-in check-out) err-invalid-dates)
        (asserts! (is-date-range-available check-in check-out) err-already-booked)
        
        (map-set bookings
            { booking-id: booking-id }
            {
                owner: tx-sender,
                check-in: check-in,
                check-out: check-out,
                status: STATUS-PENDING,
                total-amount: total-amount,
                amount-paid: u0,
                deposit-paid: u0
            }
        )
        
        (mark-dates-booked check-in check-out booking-id)
        (var-set booking-nonce booking-id)
        (emit-event "booking-created" booking-id)
        (ok booking-id)
    )
)
