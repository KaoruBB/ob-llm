;;; ob-llm.el --- org-babel integration for llm providers
;; copyright (c) 2024 Jiyan Joans Schneider
;; author: Jiyan Jonas Schneider <mail@jiyanjs.com>
;; keywords: tools, ai, babel
;; version: 0.1.0
;; package-requires: ((emacs "28.1") (org "9.6"))

;;; commentary:
;; lightweight llm integration for org-babel

;;; code:
(require 'ob)
(require 'llm)
(require 'org-element)

(defgroup ob-llm nil
  "llm babel integration"
  :group 'external)

(defvar org-babel-default-header-args:llm
  '((:async . "yes")
    (:results . "replace raw")
    (:session . "none")
    (:context . "file"))
  "Default arguments for llm source blocks.")



(defvar ob-llm-providers nil
  "Mapping of provider names to llm provider objects.
Users should populate this with their specific providers.")

(defvar ob-llm-system-prompt
  "META_PROMPT1: Follow the prompt instructions laid out below. You are an assistant living in the users' emacs. Be helpful to them. Your output will be seen their emacs.\n\n User File: "
  "System prompt for the language model.")

(defcustom ob-llm-default-provider nil
  "Default provider for llm babel blocks.
Must be set by the user to one of the registered providers in `ob-llm-providers'."
  :type '(choice (const :tag "Not Set" nil)
          (string :tag "Provider Name"))
  :group 'ob-llm)

(defun ob-llm-get-provider (params)
  "Get the llm provider from PARAMS or default.
Raises an error with helpful instructions if no provider found."
  (let* ((provider-param (cdr (assq :provider params)))
         (provider (cond
                    ;; If a provider is specified in params, look it up by name
                    (provider-param
                     (cdr (assoc provider-param ob-llm-providers)))
                    ;; If default provider is already a provider object, use it directly
                    ((and ob-llm-default-provider
                          (not (stringp ob-llm-default-provider)))
                     ob-llm-default-provider)
                    ;; If default provider is a string, look it up
                    (ob-llm-default-provider
                     (cdr (assoc ob-llm-default-provider ob-llm-providers))))))
    (unless provider
      (error "No LLM provider found.
Please set `ob-llm-default-provider' or provide a :provider parameter.
Available providers: %s"
             (mapcar #'car ob-llm-providers)))
    provider))

(defun ob-llm-get-heading-context (element)
  "Get context from current top-level heading to ELEMENT's begin."
  (save-excursion
    (goto-char (org-element-property :begin element))
    (let* ((heading (org-element-lineage element '(headline)))
           (top-heading (when heading
                          (while (and heading (> (org-element-property :level heading) 1))
                            (setq heading (org-element-property :parent heading)))
                          heading)))
      (if top-heading
          (buffer-substring-no-properties
           (org-element-property :begin top-heading)
           (org-element-property :end element))
        ""))))

(defun org-babel-execute:llm (body params)
  "Execute a block of llm code with org-babel."
  (let* ((element (org-element-at-point))
         (block-start (org-element-property :begin element))
         (context-type (or (cdr (assq :context params)) "file"))
         (context (pcase context-type
                    ("heading" (ob-llm-get-heading-context element))
                    (_ (buffer-substring-no-properties (point-min) block-start)))))
    (if (assq :async params)
        (let ((context context)) ; Store context in let binding
          (with-current-buffer (current-buffer)
            (setq-local llm-stored-params params)
            ;; (message "context %s" context)
            (org-babel-insert-result "Loading..." llm-stored-params))
          (llm-chat-async
           (ob-llm-get-provider params)
           (llm-make-chat-prompt
            (format "META_PROMPT: %s\nContext:\n%s\n\nPrompt:\n%s"
                    ob-llm-system-prompt context body))
           (lambda (response)
             (with-current-buffer (current-buffer)
               (org-babel-insert-result response llm-stored-params)))
           (lambda (err msg)
             (with-current-buffer (current-buffer)
               (org-babel-insert-result
                (format "Error: %s - %s" err msg) llm-stored-params))))
          nil)
      (llm-chat
       (ob-llm-get-provider params)
       (llm-make-chat-prompt (format "Context:\n%s\n\nPrompt:\n%s" context body))))))

;; register the language
(add-to-list 'org-babel-load-languages '(llm . t))
(org-babel-do-load-languages 'org-babel-load-languages org-babel-load-languages)

(provide 'ob-llm)
;;; ob-llm.el ends here
