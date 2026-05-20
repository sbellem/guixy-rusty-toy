;; Development shell for the guix-import-crate demo.
;;
;;   guix shell -m manifest.scm
;;
;; rust-1.94 is fetched via module-ref because on guix master it exists
;; as a private binding only.  The rest are public bindings imported
;; via use-modules.

(use-modules (guix profiles)
             (gnu packages certs)
             (gnu packages nss)
             (gnu packages tls)
             (gnu packages version-control))

(define rust-1.94
  (module-ref (resolve-module '(gnu packages rust)) 'rust-1.94))

(packages->manifest
 (list rust-1.94
       (list rust-1.94 "cargo")
       git
       openssl
       nss-certs))
