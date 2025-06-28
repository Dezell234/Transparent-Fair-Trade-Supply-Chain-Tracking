(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-stage (err u103))
(define-constant err-already-exists (err u104))
(define-constant err-invalid-input (err u105))

(define-data-var next-product-id uint u1)
(define-data-var next-producer-id uint u1)
(define-data-var next-certification-id uint u1)

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
        (ok next-stage)
    )
)

(define-public (verify-stage (product-id uint) (stage uint))
    (let ((stage-data (unwrap! (map-get? supply-chain-stages {product-id: product-id, stage: stage}) err-not-found)))
        (asserts! (default-to false (map-get? authorized-handlers tx-sender)) err-unauthorized)
        (map-set supply-chain-stages {product-id: product-id, stage: stage}
            (merge stage-data {verified: true}))
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



