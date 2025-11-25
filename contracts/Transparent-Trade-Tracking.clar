(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-stage (err u103))
(define-constant err-already-exists (err u104))
(define-constant err-invalid-input (err u105))
(define-constant err-insufficient-funds (err u106))
(define-constant err-no-premium-available (err u107))
(define-constant err-dispute-exists (err u108))
(define-constant err-dispute-resolved (err u109))
(define-constant err-invalid-evidence (err u110))
(define-constant err-cannot-vote-own-dispute (err u111))
(define-constant err-product-recalled (err u112))

(define-data-var next-product-id uint u1)
(define-data-var next-producer-id uint u1)
(define-data-var next-certification-id uint u1)
(define-data-var total-premium-pool uint u0)
(define-data-var next-dispute-id uint u1)
(define-data-var next-consumer-id uint u1)
(define-data-var next-purchase-id uint u1)

(define-map producers uint {
    name: (string-ascii 50),
    location: (string-ascii 100),
    wallet: principal,
    certified: bool,
    registration-block: uint
})

(define-map certifications uint {
    producer-id: uint,
    certification-type: (string-ascii 30),
    issuer: (string-ascii 50),
    valid-until: uint,
    issued-block: uint
})

(define-map products uint {
    producer-id: uint,
    product-type: (string-ascii 30),
    batch-id: (string-ascii 50),
    quantity: uint,
    current-stage: uint,
    current-holder: principal,
    created-block: uint,
    fair-trade-premium: uint
})

(define-map supply-chain-stages {product-id: uint, stage: uint} {
    stage-name: (string-ascii 30),
    handler: principal,
    location: (string-ascii 100),
    timestamp: uint,
    notes: (string-ascii 200),
    verified: bool
})

(define-map authorized-handlers principal bool)

(define-map product-certifications {product-id: uint, cert-id: uint} bool)

(define-map premium-distributions {producer-id: uint, period: uint} {
    total-earned: uint,
    base-premium: uint,
    reputation-bonus: uint,
    distributed-block: uint,
    period-products: uint
})

(define-map producer-reputation uint {
    total-products: uint,
    verified-stages: uint,
    total-stages: uint,
    on-time-deliveries: uint,
    late-deliveries: uint,
    quality-score: uint,
    reputation-score: uint,
    last-updated: uint
})

(define-map quality-disputes uint {
    product-id: uint,
    stage: uint,
    complainant: principal,
    dispute-type: (string-ascii 20),
    evidence-hash: (string-ascii 64),
    description: (string-ascii 200),
    status: uint,
    created-block: uint,
    resolution-block: uint,
    validator-votes: uint,
    total-votes: uint,
    stake-amount: uint
})

(define-map dispute-votes {dispute-id: uint, voter: principal} {
    vote: bool,
    stake: uint,
    voting-block: uint
})

(define-map dispute-validators {dispute-id: uint, validator: principal} bool)

(define-map consumers principal {
    consumer-id: uint,
    total-purchases: uint,
    total-reward-points: uint,
    redeemed-points: uint,
    available-points: uint,
    registration-block: uint,
    last-purchase-block: uint
})

(define-map consumer-purchases uint {
    consumer: principal,
    product-id: uint,
    producer-id: uint,
    purchase-amount: uint,
    reward-points-earned: uint,
    purchase-block: uint,
    producer-reputation-at-time: uint
})

(define-map reward-redemptions uint {
    consumer: principal,
    points-redeemed: uint,
    redemption-value: uint,
    redemption-block: uint,
    redemption-type: (string-ascii 30)
})

(define-map product-recalls uint {
    reason: (string-ascii 200),
    recalled-block: uint,
    recalled-by: principal
})

(define-map batch-recalls {producer-id: uint, batch-id: (string-ascii 50)} {
    reason: (string-ascii 200),
    recalled-block: uint,
    recalled-by: principal
})

(define-read-only (is-product-recalled (product-id uint))
    (match (map-get? products product-id)
        product (or 
            (is-some (map-get? product-recalls product-id))
            (is-some (map-get? batch-recalls {producer-id: (get producer-id product), batch-id: (get batch-id product)}))
        )
        false
    )
)

(define-public (register-producer (name (string-ascii 50)) (location (string-ascii 100)) (wallet principal))
    (let ((producer-id (var-get next-producer-id)))
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> (len name) u0) err-invalid-input)
        (asserts! (> (len location) u0) err-invalid-input)
        (map-set producers producer-id {
            name: name,
            location: location,
            wallet: wallet,
            certified: false,
            registration-block: stacks-block-height
        })
        (map-set producer-reputation producer-id {
            total-products: u0,
            verified-stages: u0,
            total-stages: u0,
            on-time-deliveries: u0,
            late-deliveries: u0,
            quality-score: u100,
            reputation-score: u100,
            last-updated: stacks-block-height
        })
        (var-set next-producer-id (+ producer-id u1))
        (ok producer-id)
    )
)

(define-public (add-certification (producer-id uint) (cert-type (string-ascii 30)) (issuer (string-ascii 50)) (valid-blocks uint))
    (let ((cert-id (var-get next-certification-id)))
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-some (map-get? producers producer-id)) err-not-found)
        (asserts! (> (len cert-type) u0) err-invalid-input)
        (asserts! (> (len issuer) u0) err-invalid-input)
        (map-set certifications cert-id {
            producer-id: producer-id,
            certification-type: cert-type,
            issuer: issuer,
            valid-until: (+ stacks-block-height valid-blocks),
            issued-block: stacks-block-height
        })
        (map-set producers producer-id 
            (merge (unwrap! (map-get? producers producer-id) err-not-found) {certified: true}))
        (var-set next-certification-id (+ cert-id u1))
        (ok cert-id)
    )
)

(define-public (create-product (producer-id uint) (product-type (string-ascii 30)) (batch-id (string-ascii 50)) (quantity uint) (fair-trade-premium uint))
    (let ((product-id (var-get next-product-id))
          (producer (unwrap! (map-get? producers producer-id) err-not-found)))
        (asserts! (is-eq tx-sender (get wallet producer)) err-unauthorized)
        (asserts! (> (len product-type) u0) err-invalid-input)
        (asserts! (> (len batch-id) u0) err-invalid-input)
        (asserts! (> quantity u0) err-invalid-input)
        (map-set products product-id {
            producer-id: producer-id,
            product-type: product-type,
            batch-id: batch-id,
            quantity: quantity,
            current-stage: u0,
            current-holder: tx-sender,
            created-block: stacks-block-height,
            fair-trade-premium: fair-trade-premium
        })
        (map-set supply-chain-stages {product-id: product-id, stage: u0} {
            stage-name: "Production",
            handler: tx-sender,
            location: (get location producer),
            timestamp: stacks-block-height,
            notes: "Product created at farm",
            verified: true
        })
        (try! (update-producer-products-count producer-id))
        (var-set total-premium-pool (+ (var-get total-premium-pool) fair-trade-premium))
        (var-set next-product-id (+ product-id u1))
        (ok product-id)
    )
)

(define-public (authorize-handler (handler principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set authorized-handlers handler true)
        (ok true)
    )
)

(define-public (revoke-handler (handler principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-delete authorized-handlers handler)
        (ok true)
    )
)

(define-public (update-supply-chain-stage (product-id uint) (stage-name (string-ascii 30)) (location (string-ascii 100)) (notes (string-ascii 200)))
    (let ((product (unwrap! (map-get? products product-id) err-not-found))
          (current-stage (get current-stage product))
          (next-stage (+ current-stage u1)))
        (asserts! (or (is-eq tx-sender (get current-holder product))
                     (default-to false (map-get? authorized-handlers tx-sender))) err-unauthorized)
        (asserts! (not (is-product-recalled product-id)) err-product-recalled)
        (asserts! (> (len stage-name) u0) err-invalid-input)
        (asserts! (> (len location) u0) err-invalid-input)
        (map-set supply-chain-stages {product-id: product-id, stage: next-stage} {
            stage-name: stage-name,
            handler: tx-sender,
            location: location,
            timestamp: stacks-block-height,
            notes: notes,
            verified: false
        })
        (map-set products product-id 
            (merge product {current-stage: next-stage, current-holder: tx-sender}))
        (try! (update-producer-stage-count (get producer-id product)))
        (ok next-stage)
    )
)

(define-public (verify-stage (product-id uint) (stage uint))
    (let ((stage-data (unwrap! (map-get? supply-chain-stages {product-id: product-id, stage: stage}) err-not-found)))
        (asserts! (default-to false (map-get? authorized-handlers tx-sender)) err-unauthorized)
        (map-set supply-chain-stages {product-id: product-id, stage: stage}
            (merge stage-data {verified: true}))
        (let ((product (unwrap! (map-get? products product-id) err-not-found)))
            (try! (update-producer-verified-count (get producer-id product))))
        (ok true)
    )
)

(define-public (link-product-certification (product-id uint) (cert-id uint))
    (let ((product (unwrap! (map-get? products product-id) err-not-found))
          (certification (unwrap! (map-get? certifications cert-id) err-not-found)))
        (asserts! (is-eq (get producer-id product) (get producer-id certification)) err-unauthorized)
        (asserts! (> (get valid-until certification) stacks-block-height) err-invalid-input)
        (map-set product-certifications {product-id: product-id, cert-id: cert-id} true)
        (ok true)
    )
)

(define-public (transfer-custody (product-id uint) (new-holder principal))
    (let ((product (unwrap! (map-get? products product-id) err-not-found)))
        (asserts! (is-eq tx-sender (get current-holder product)) err-unauthorized)
        (asserts! (not (is-product-recalled product-id)) err-product-recalled)
        (map-set products product-id 
            (merge product {current-holder: new-holder}))
        (ok true)
    )
)

(define-read-only (get-producer (producer-id uint))
    (map-get? producers producer-id)
)

(define-read-only (get-product (product-id uint))
    (map-get? products product-id)
)

(define-read-only (get-certification (cert-id uint))
    (map-get? certifications cert-id)
)

(define-read-only (get-supply-chain-stage (product-id uint) (stage uint))
    (map-get? supply-chain-stages {product-id: product-id, stage: stage})
)

(define-read-only (is-handler-authorized (handler principal))
    (default-to false (map-get? authorized-handlers handler))
)

(define-read-only (is-product-certified (product-id uint) (cert-id uint))
    (default-to false (map-get? product-certifications {product-id: product-id, cert-id: cert-id}))
)

(define-read-only (get-next-product-id)
    (var-get next-product-id)
)

(define-read-only (get-next-producer-id)
    (var-get next-producer-id)
)

(define-read-only (get-next-certification-id)
    (var-get next-certification-id)
)

(define-read-only (get-product-trace (product-id uint))
    (match (map-get? products product-id)
        prod (some {
            product: prod,
            stage-0: (map-get? supply-chain-stages {product-id: product-id, stage: u0}),
            stage-1: (map-get? supply-chain-stages {product-id: product-id, stage: u1}),
            stage-2: (map-get? supply-chain-stages {product-id: product-id, stage: u2}),
            stage-3: (map-get? supply-chain-stages {product-id: product-id, stage: u3}),
            stage-4: (map-get? supply-chain-stages {product-id: product-id, stage: u4})
        })
        none
    )
)

(define-private (update-producer-products-count (producer-id uint))
    (let ((current-rep (default-to {
            total-products: u0,
            verified-stages: u0,
            total-stages: u0,
            on-time-deliveries: u0,
            late-deliveries: u0,
            quality-score: u100,
            reputation-score: u100,
            last-updated: stacks-block-height
        } (map-get? producer-reputation producer-id))))
        (map-set producer-reputation producer-id 
            (merge current-rep {
                total-products: (+ (get total-products current-rep) u1),
                last-updated: stacks-block-height
            }))
        (calculate-reputation-score producer-id)
    )
)

(define-private (update-producer-stage-count (producer-id uint))
    (let ((current-rep (unwrap! (map-get? producer-reputation producer-id) err-not-found)))
        (map-set producer-reputation producer-id 
            (merge current-rep {
                total-stages: (+ (get total-stages current-rep) u1),
                last-updated: stacks-block-height
            }))
        (calculate-reputation-score producer-id)
    )
)

(define-private (update-producer-verified-count (producer-id uint))
    (let ((current-rep (unwrap! (map-get? producer-reputation producer-id) err-not-found)))
        (map-set producer-reputation producer-id 
            (merge current-rep {
                verified-stages: (+ (get verified-stages current-rep) u1),
                last-updated: stacks-block-height
            }))
        (calculate-reputation-score producer-id)
    )
)

(define-private (calculate-reputation-score (producer-id uint))
    (let ((rep (unwrap! (map-get? producer-reputation producer-id) err-not-found))
          (verification-rate (if (> (get total-stages rep) u0)
                                (/ (* (get verified-stages rep) u100) (get total-stages rep))
                                u100))
          (delivery-rate (if (> (+ (get on-time-deliveries rep) (get late-deliveries rep)) u0)
                            (/ (* (get on-time-deliveries rep) u100) 
                               (+ (get on-time-deliveries rep) (get late-deliveries rep)))
                            u100))
          (weighted-score (/ (+ (* verification-rate u40) 
                               (* delivery-rate u30) 
                               (* (get quality-score rep) u30)) u100)))
        (map-set producer-reputation producer-id 
            (merge rep {reputation-score: weighted-score}))
        (ok weighted-score)
    )
)

(define-public (update-delivery-status (producer-id uint) (on-time bool))
    (let ((current-rep (unwrap! (map-get? producer-reputation producer-id) err-not-found)))
        (asserts! (default-to false (map-get? authorized-handlers tx-sender)) err-unauthorized)
        (if on-time
            (map-set producer-reputation producer-id 
                (merge current-rep {
                    on-time-deliveries: (+ (get on-time-deliveries current-rep) u1),
                    last-updated: stacks-block-height
                }))
            (map-set producer-reputation producer-id 
                (merge current-rep {
                    late-deliveries: (+ (get late-deliveries current-rep) u1),
                    last-updated: stacks-block-height
                })))
        (calculate-reputation-score producer-id)
    )
)

(define-public (update-quality-score (producer-id uint) (quality-score uint))
    (let ((current-rep (unwrap! (map-get? producer-reputation producer-id) err-not-found)))
        (asserts! (default-to false (map-get? authorized-handlers tx-sender)) err-unauthorized)
        (asserts! (<= quality-score u100) err-invalid-input)
        (map-set producer-reputation producer-id 
            (merge current-rep {
                quality-score: quality-score,
                last-updated: stacks-block-height
            }))
        (calculate-reputation-score producer-id)
    )
)

(define-read-only (get-producer-reputation (producer-id uint))
    (map-get? producer-reputation producer-id)
)

(define-read-only (get-reputation-score (producer-id uint))
    (match (map-get? producer-reputation producer-id)
        rep (some (get reputation-score rep))
        none
    )
)

(define-public (distribute-premium (producer-id uint) (period uint))
    (let ((producer (unwrap! (map-get? producers producer-id) err-not-found))
          (reputation (unwrap! (map-get? producer-reputation producer-id) err-not-found))
          (reputation-score (get reputation-score reputation))
          (total-products (get total-products reputation))
          (existing-distribution (map-get? premium-distributions {producer-id: producer-id, period: period})))
        (asserts! (default-to false (map-get? authorized-handlers tx-sender)) err-unauthorized)
        (asserts! (is-none existing-distribution) err-already-exists)
        (asserts! (> total-products u0) err-no-premium-available)
        (let ((period-products (calculate-period-products producer-id period))
              (base-premium-per-product u1000)
              (base-premium (* period-products base-premium-per-product))
              (reputation-multiplier (/ reputation-score u100))
              (reputation-bonus (if (> reputation-score u80)
                                   (/ (* base-premium (- reputation-score u80)) u100)
                                   u0))
              (total-distribution (+ base-premium reputation-bonus)))
            (asserts! (> (var-get total-premium-pool) total-distribution) err-insufficient-funds)
            (map-set premium-distributions {producer-id: producer-id, period: period} {
                total-earned: total-distribution,
                base-premium: base-premium,
                reputation-bonus: reputation-bonus,
                distributed-block: stacks-block-height,
                period-products: period-products
            })
            (var-set total-premium-pool (- (var-get total-premium-pool) total-distribution))
            (try! (stx-transfer? total-distribution tx-sender (get wallet producer)))
            (ok total-distribution)
        )
    )
)

(define-public (fund-premium-pool (amount uint))
    (begin
        (asserts! (> amount u0) err-invalid-input)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (var-set total-premium-pool (+ (var-get total-premium-pool) amount))
        (ok (var-get total-premium-pool))
    )
)

(define-private (calculate-period-products (producer-id uint) (period uint))
    (let ((target-block-start (* period u1000))
          (target-block-end (* (+ period u1) u1000))
          (result (fold count-products-in-period 
                        (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20)
                        {producer-id: producer-id, period-start: target-block-start, period-end: target-block-end, count: u0})))
        (get count result)
    )
)

(define-private (count-products-in-period (product-index uint) (context {producer-id: uint, period-start: uint, period-end: uint, count: uint}))
    (let ((product-id product-index))
        (match (map-get? products product-id)
            product (if (and (is-eq (get producer-id product) (get producer-id context))
                           (>= (get created-block product) (get period-start context))
                           (< (get created-block product) (get period-end context)))
                       (merge context {count: (+ (get count context) u1)})
                       context)
            context
        )
    )
)

(define-read-only (get-premium-distribution (producer-id uint) (period uint))
    (map-get? premium-distributions {producer-id: producer-id, period: period})
)

(define-read-only (get-total-premium-pool)
    (var-get total-premium-pool)
)

(define-read-only (calculate-projected-premium (producer-id uint) (period uint))
    (let ((reputation (default-to {
            total-products: u0,
            verified-stages: u0,
            total-stages: u0,
            on-time-deliveries: u0,
            late-deliveries: u0,
            quality-score: u100,
            reputation-score: u100,
            last-updated: stacks-block-height
        } (map-get? producer-reputation producer-id)))
          (reputation-score (get reputation-score reputation))
          (period-products (calculate-period-products producer-id period))
          (base-premium-per-product u1000)
          (base-premium (* period-products base-premium-per-product))
          (reputation-bonus (if (> reputation-score u80)
                               (/ (* base-premium (- reputation-score u80)) u100)
                               u0)))
        (some {
            projected-total: (+ base-premium reputation-bonus),
            base-amount: base-premium,
            reputation-bonus: reputation-bonus,
            period-products: period-products,
            current-reputation-score: reputation-score
        })
    )
)

(define-public (raise-quality-dispute (product-id uint) (stage uint) (dispute-type (string-ascii 20)) (evidence-hash (string-ascii 64)) (description (string-ascii 200)) (stake-amount uint))
    (let ((dispute-id (var-get next-dispute-id))
          (product (unwrap! (map-get? products product-id) err-not-found))
          (stage-data (unwrap! (map-get? supply-chain-stages {product-id: product-id, stage: stage}) err-not-found)))
        (asserts! (> (len dispute-type) u0) err-invalid-input)
        (asserts! (> (len evidence-hash) u0) err-invalid-evidence)
        (asserts! (> (len description) u0) err-invalid-input)
        (asserts! (> stake-amount u0) err-invalid-input)
        (asserts! (is-none (get-active-dispute-for-stage product-id stage)) err-dispute-exists)
        (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
        (map-set quality-disputes dispute-id {
            product-id: product-id,
            stage: stage,
            complainant: tx-sender,
            dispute-type: dispute-type,
            evidence-hash: evidence-hash,
            description: description,
            status: u0,
            created-block: stacks-block-height,
            resolution-block: u0,
            validator-votes: u0,
            total-votes: u0,
            stake-amount: stake-amount
        })
        (var-set next-dispute-id (+ dispute-id u1))
        (ok dispute-id)
    )
)

(define-public (vote-on-dispute (dispute-id uint) (support-complainant bool) (validator-stake uint))
    (let ((dispute (unwrap! (map-get? quality-disputes dispute-id) err-not-found)))
        (asserts! (is-eq (get status dispute) u0) err-dispute-resolved)
        (asserts! (not (is-eq tx-sender (get complainant dispute))) err-cannot-vote-own-dispute)
        (asserts! (default-to false (map-get? authorized-handlers tx-sender)) err-unauthorized)
        (asserts! (is-none (map-get? dispute-votes {dispute-id: dispute-id, voter: tx-sender})) err-already-exists)
        (asserts! (> validator-stake u0) err-invalid-input)
        (try! (stx-transfer? validator-stake tx-sender (as-contract tx-sender)))
        (map-set dispute-votes {dispute-id: dispute-id, voter: tx-sender} {
            vote: support-complainant,
            stake: validator-stake,
            voting-block: stacks-block-height
        })
        (map-set dispute-validators {dispute-id: dispute-id, validator: tx-sender} true)
        (let ((updated-dispute (merge dispute {
            validator-votes: (if support-complainant (+ (get validator-votes dispute) u1) (get validator-votes dispute)),
            total-votes: (+ (get total-votes dispute) u1)
        })))
            (map-set quality-disputes dispute-id updated-dispute)
            (if (>= (get total-votes updated-dispute) u3)
                (auto-resolve-dispute dispute-id)
                (ok true))
        )
    )
)

(define-public (resolve-dispute (dispute-id uint))
    (let ((dispute (unwrap! (map-get? quality-disputes dispute-id) err-not-found)))
        (asserts! (default-to false (map-get? authorized-handlers tx-sender)) err-unauthorized)
        (asserts! (is-eq (get status dispute) u0) err-dispute-resolved)
        (asserts! (>= (get total-votes dispute) u3) err-invalid-input)
        (auto-resolve-dispute dispute-id)
    )
)

(define-private (auto-resolve-dispute (dispute-id uint))
    (let ((dispute (unwrap! (map-get? quality-disputes dispute-id) err-not-found))
          (majority-threshold (/ (get total-votes dispute) u2))
          (complainant-supported (> (get validator-votes dispute) majority-threshold))
          (resolution-status (if complainant-supported u1 u2)))
        (map-set quality-disputes dispute-id 
            (merge dispute {
                status: resolution-status,
                resolution-block: stacks-block-height
            }))
        (if complainant-supported
            (begin
                (try! (stx-transfer? (get stake-amount dispute) (as-contract tx-sender) (get complainant dispute)))
                (try! (penalize-stage-handler dispute-id))
                (ok true))
            (begin
                (ok true))
        )
    )
)

(define-private (penalize-stage-handler (dispute-id uint))
    (let ((dispute (unwrap! (map-get? quality-disputes dispute-id) err-not-found))
          (product-id (get product-id dispute))
          (stage (get stage dispute))
          (stage-data (unwrap! (map-get? supply-chain-stages {product-id: product-id, stage: stage}) err-not-found))
          (handler (get handler stage-data)))
        (map-set supply-chain-stages {product-id: product-id, stage: stage}
            (merge stage-data {verified: false}))
        (let ((product (unwrap! (map-get? products product-id) err-not-found))
              (producer-id (get producer-id product)))
            (update-producer-quality-penalty producer-id))
    )
)

(define-private (update-producer-quality-penalty (producer-id uint))
    (let ((current-rep (unwrap! (map-get? producer-reputation producer-id) err-not-found))
          (penalty-amount u5)
          (new-quality-score (if (> (get quality-score current-rep) penalty-amount)
                               (- (get quality-score current-rep) penalty-amount)
                               u0)))
        (map-set producer-reputation producer-id 
            (merge current-rep {
                quality-score: new-quality-score,
                last-updated: stacks-block-height
            }))
        (calculate-reputation-score producer-id)
    )
)

(define-private (get-active-dispute-for-stage (product-id uint) (stage uint))
    (let ((dispute-check (fold check-active-disputes
                             (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10)
                             {target-product: product-id, target-stage: stage, found-active: none})))
        (get found-active dispute-check)
    )
)

(define-private (check-active-disputes (dispute-id uint) (context {target-product: uint, target-stage: uint, found-active: (optional uint)}))
    (if (is-some (get found-active context))
        context
        (match (map-get? quality-disputes dispute-id)
            dispute (if (and (is-eq (get product-id dispute) (get target-product context))
                           (is-eq (get stage dispute) (get target-stage context))
                           (is-eq (get status dispute) u0))
                       (merge context {found-active: (some dispute-id)})
                       context)
            context
        )
    )
)

(define-read-only (get-dispute (dispute-id uint))
    (map-get? quality-disputes dispute-id)
)

(define-read-only (get-dispute-vote (dispute-id uint) (voter principal))
    (map-get? dispute-votes {dispute-id: dispute-id, voter: voter})
)

(define-read-only (get-dispute-status (dispute-id uint))
    (match (map-get? quality-disputes dispute-id)
        dispute (some (get status dispute))
        none
    )
)

(define-read-only (get-next-dispute-id)
    (var-get next-dispute-id)
)

(define-public (register-consumer)
    (let ((existing-consumer (map-get? consumers tx-sender)))
        (asserts! (is-none existing-consumer) err-already-exists)
        (let ((consumer-id (var-get next-consumer-id)))
            (map-set consumers tx-sender {
                consumer-id: consumer-id,
                total-purchases: u0,
                total-reward-points: u0,
                redeemed-points: u0,
                available-points: u0,
                registration-block: stacks-block-height,
                last-purchase-block: u0
            })
            (var-set next-consumer-id (+ consumer-id u1))
            (ok consumer-id)
        )
    )
)

(define-public (record-consumer-purchase (product-id uint) (purchase-amount uint))
    (let ((product (unwrap! (map-get? products product-id) err-not-found))
          (producer-id (get producer-id product))
          (producer-rep (unwrap! (map-get? producer-reputation producer-id) err-not-found))
          (consumer-data (unwrap! (map-get? consumers tx-sender) err-not-found))
          (purchase-id (var-get next-purchase-id)))
        (asserts! (> purchase-amount u0) err-invalid-input)
        (let ((base-points (/ purchase-amount u100))
              (reputation-multiplier (get reputation-score producer-rep))
              (bonus-points (/ (* base-points reputation-multiplier) u100))
              (total-points (+ base-points bonus-points)))
            (map-set consumer-purchases purchase-id {
                consumer: tx-sender,
                product-id: product-id,
                producer-id: producer-id,
                purchase-amount: purchase-amount,
                reward-points-earned: total-points,
                purchase-block: stacks-block-height,
                producer-reputation-at-time: reputation-multiplier
            })
            (map-set consumers tx-sender 
                (merge consumer-data {
                    total-purchases: (+ (get total-purchases consumer-data) u1),
                    total-reward-points: (+ (get total-reward-points consumer-data) total-points),
                    available-points: (+ (get available-points consumer-data) total-points),
                    last-purchase-block: stacks-block-height
                }))
            (var-set next-purchase-id (+ purchase-id u1))
            (ok {purchase-id: purchase-id, points-earned: total-points})
        )
    )
)

(define-public (redeem-reward-points (points-to-redeem uint) (redemption-type (string-ascii 30)))
    (let ((consumer-data (unwrap! (map-get? consumers tx-sender) err-not-found)))
        (asserts! (> points-to-redeem u0) err-invalid-input)
        (asserts! (>= (get available-points consumer-data) points-to-redeem) err-insufficient-funds)
        (asserts! (> (len redemption-type) u0) err-invalid-input)
        (let ((redemption-id (var-get next-purchase-id))
              (redemption-value (/ (* points-to-redeem u10) u1)))
            (map-set reward-redemptions redemption-id {
                consumer: tx-sender,
                points-redeemed: points-to-redeem,
                redemption-value: redemption-value,
                redemption-block: stacks-block-height,
                redemption-type: redemption-type
            })
            (map-set consumers tx-sender 
                (merge consumer-data {
                    redeemed-points: (+ (get redeemed-points consumer-data) points-to-redeem),
                    available-points: (- (get available-points consumer-data) points-to-redeem)
                }))
            (try! (stx-transfer? redemption-value (as-contract tx-sender) tx-sender))
            (ok redemption-value)
        )
    )
)

(define-public (recall-product (product-id uint) (reason (string-ascii 200)))
    (let ((product (unwrap! (map-get? products product-id) err-not-found))
          (producer (unwrap! (map-get? producers (get producer-id product)) err-not-found)))
        (asserts! (is-eq tx-sender (get wallet producer)) err-unauthorized)
        (asserts! (> (len reason) u0) err-invalid-input)
        (map-set product-recalls product-id {
            reason: reason,
            recalled-block: stacks-block-height,
            recalled-by: tx-sender
        })
        (ok true)
    )
)

(define-public (recall-batch (producer-id uint) (batch-id (string-ascii 50)) (reason (string-ascii 200)))
    (let ((producer (unwrap! (map-get? producers producer-id) err-not-found)))
        (asserts! (is-eq tx-sender (get wallet producer)) err-unauthorized)
        (asserts! (> (len batch-id) u0) err-invalid-input)
        (asserts! (> (len reason) u0) err-invalid-input)
        (map-set batch-recalls {producer-id: producer-id, batch-id: batch-id} {
            reason: reason,
            recalled-block: stacks-block-height,
            recalled-by: tx-sender
        })
        (ok true)
    )
)

(define-read-only (get-consumer-profile (consumer principal))
    (map-get? consumers consumer)
)

(define-read-only (get-consumer-purchase (purchase-id uint))
    (map-get? consumer-purchases purchase-id)
)

(define-read-only (get-reward-redemption (redemption-id uint))
    (map-get? reward-redemptions redemption-id)
)

(define-read-only (get-consumer-available-points (consumer principal))
    (match (map-get? consumers consumer)
        consumer-data (some (get available-points consumer-data))
        none
    )
)

(define-read-only (calculate-potential-rewards (product-id uint) (purchase-amount uint))
    (match (map-get? products product-id)
        product (let ((producer-id (get producer-id product)))
            (match (map-get? producer-reputation producer-id)
                producer-rep (let ((base-points (/ purchase-amount u100))
                                  (reputation-multiplier (get reputation-score producer-rep))
                                  (bonus-points (/ (* base-points reputation-multiplier) u100))
                                  (total-points (+ base-points bonus-points)))
                    (some {
                        base-points: base-points,
                        bonus-points: bonus-points,
                        total-points: total-points,
                        producer-reputation: reputation-multiplier
                    }))
                none
            ))
        none
    )
)

(define-read-only (get-next-consumer-id)
    (var-get next-consumer-id)
)

(define-read-only (get-next-purchase-id)
    (var-get next-purchase-id)
)



