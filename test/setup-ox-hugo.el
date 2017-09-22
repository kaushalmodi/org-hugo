;; Time-stamp: <2017-09-22 16:35:43 kmodi>

;; Setup to test ox-hugo using emacs -Q and the latest stable version of Org

;; Some sane settings
(setq-default require-final-newline t)
(setq-default indent-tabs-mode nil)

(defvar ox-hugo-elpa (let ((dir (getenv "OX_HUGO_ELPA")))
                       (unless dir
                         (setq dir (concat (temporary-file-directory) (getenv "USER") "/ox-hugo-dev/")))
                       (make-directory (file-name-as-directory dir) :parents)
                       dir))
(message "ox-hugo-elpa: %S" ox-hugo-elpa)

(let* ((bin-dir (when (and invocation-directory
                           (file-exists-p invocation-directory))
                  (file-truename invocation-directory)))
       (prefix-dir (when bin-dir
                     (replace-regexp-in-string "bin/\\'" "" bin-dir)))
       (share-dir (when prefix-dir
                    (concat prefix-dir "share/")))
       (lisp-dir-1 (when share-dir ;Possibility where the lisp dir is something like ../emacs/26.0.50/lisp/
                     (concat share-dir "emacs/"
                             ;; If `emacs-version' is x.y.z.w, remove the ".w" portion
                             ;; Though, this is not needed and also will do nothing in emacs 26+
                             ;; http://git.savannah.gnu.org/cgit/emacs.git/commit/?id=22b2207471807bda86534b4faf1a29b3a6447536
                             (replace-regexp-in-string "\\([0-9]+\\.[0-9]+\\.[0-9]+\\).*" "\\1" emacs-version)
                             "/lisp/")))
       (lisp-dir-2 (when share-dir ;Possibility where the lisp dir is something like ../emacs/25.2/lisp/
                     (concat share-dir "emacs/"
                             (replace-regexp-in-string "\\([0-9]+\\.[0-9]+\\).*" "\\1" emacs-version)
                             "/lisp/"))))
  (message "emacs bin-dir: %s" bin-dir)
  (message "emacs prefix-dir: %s" prefix-dir)
  (message "emacs share-dir: %s" share-dir)
  (message "emacs lisp-dir-1: %s" lisp-dir-1)
  (message "emacs lisp-dir-2: %s" lisp-dir-2)
  (defvar my/default-lisp-directory (cond
                                     ((file-exists-p lisp-dir-1)
                                      lisp-dir-1)
                                     ((file-exists-p lisp-dir-2)
                                      lisp-dir-2)
                                     (t
                                      nil))
    "Directory containing lisp files for the Emacs installation.

This value must match the path to the lisp/ directory of the
Emacs installation.  If Emacs is installed using
--prefix=\"${PREFIX_DIR}\" this value would typically be
\"${PREFIX_DIR}/share/emacs/<VERSION>/lisp/\"."))
(message "my/default-lisp-directory: %S" my/default-lisp-directory)

;; `org' will always be detected as installed, so use `org-plus-contrib'.
(defvar my/packages '(org-plus-contrib))

(if (and (stringp ox-hugo-elpa)
         (file-exists-p ox-hugo-elpa))
    (progn
      ;; Load newer version of .el and .elc if both are available
      (setq load-prefer-newer t)

      (setq package-user-dir (format "%selpa_%s/" ox-hugo-elpa emacs-major-version))

      ;; Below require will auto-create `package-user-dir' it doesn't exist.
      (require 'package)

      ;; Adding Melpa is not needed for now.
      ;; (let* ((no-ssl (and (memq system-type '(windows-nt ms-dos))
      ;;                     (not (gnutls-available-p))))
      ;;        (url (concat (if no-ssl "http" "https") "://melpa.org/packages/")))
      ;;   (add-to-list 'package-archives (cons "melpa" url) :append))
      (add-to-list 'package-archives '("org" . "http://orgmode.org/elpa/") :append) ;For latest `org'

      (defvar ox-hugo-git-root (progn
                                 (require 'vc-git)
                                 (vc-git-root ".")))
      (message "ox-hugo-git-root: %S" ox-hugo-git-root)
      (add-to-list 'load-path ox-hugo-git-root)

      ;; Load emacs packages and activate them.
      ;; Don't delete this line.
      (package-initialize)
      ;; `package-initialize' call is required before any of the below
      ;; can happen.

      (defvar my/missing-packages '()
        "List populated at each startup that contains the list of packages that need
to be installed.")

      (dolist (p my/packages)
        ;; (message "Is %S installed? %s" p (package-installed-p p))
        (unless (package-installed-p p)
          (add-to-list 'my/missing-packages p)))

      (when my/missing-packages
        (message "Emacs is now refreshing its package database...")
        (package-refresh-contents)
        ;; Install the missing packages
        (dolist (p my/missing-packages)
          (message "Installing `%s' .." p)
          (package-install p))
        (setq my/missing-packages '())))
  (error "The environment variable OX_HUGO_ELPA needs to be set"))

(with-eval-after-load 'package
  ;; Remove Org that ships with Emacs from the `load-path'.
  (when (stringp my/default-lisp-directory)
    (dolist (path load-path)
      (when (string-match-p (expand-file-name "org" my/default-lisp-directory) path)
        (setq load-path (delete path load-path))))))

;; (message "`load-path': %S" load-path)
;; (message "`load-path' Shadows:")
;; (message (list-load-path-shadows :stringp))

(require 'ox-hugo)
(defun org-hugo-export-all-subtrees-to-md ()
  (org-hugo-export-subtree-to-md :all-subtrees))

(with-eval-after-load 'org
  ;; Allow multiple line Org emphasis markup
  ;; http://emacs.stackexchange.com/a/13828/115
  (setcar (nthcdr 4 org-emphasis-regexp-components) 20) ;Up to 20 lines, default is just 1
  ;; Below is needed to apply the modified `org-emphasis-regexp-components'
  ;; settings from above.
  (org-set-emph-re 'org-emphasis-regexp-components org-emphasis-regexp-components)

  ;; Prevent prompts like:
  ;;   Non-existent agenda file
  (defun org-check-agenda-file (file)))

(with-eval-after-load 'ox
  (setq org-export-with-sub-superscripts '{}))

(with-eval-after-load 'ox-hugo
  (setq org-hugo-langs-no-descr-in-code-fences '(org)))

;; Wed Sep 20 13:37:06 EDT 2017 - kmodi
;; Below does not get applies when running emacs --batch.. need to
;; figure out a solution.
(custom-set-variables
 '(safe-local-variable-values
   (quote
    ((org-hugo-footer . "

[//]: # \"Exported with love from a post written in Org mode\"
[//]: # \"- https://github.com/kaushalmodi/ox-hugo\"")))))
