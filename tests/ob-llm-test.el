(ert-deftest ob-llm-test-extract-provider ()
  (let ((qwen-provider (ob-llm-extract-provider 'qwen ob-llm-providers)))
    (should qwen-provider)
    (should (eq (type-of qwen-provider) 'llm-ollama))
    (should (string-match-p "qwen" (format "%S" qwen-provider)))))

(ert-deftest ob-llm-test-get-provider ()
    ;; Test getting provider by default
    (should (ob-llm-get-provider '(haiku))))

(ert-deftest ob-llm-test-extract-provider ()
  (let ((params '((:async . nil) (:provider . "qwen")))
        (body "What is 2+2?"))
    (should (stringp (org-babel-execute:llm body params)))))

(ert-deftest ob-llm-test-heading-context ()
  (with-temp-buffer
    (org-mode)
    (insert "*FIRST HEADLINE \n* Top\nsome content\n** Sub\nmore stuff\n*** Here\nfinal text\n* Another headline \n HERE")
    (goto-char 50)
    (should (string= (ob-llm-get-heading-context (org-element-at-point))
                     "* Top\nsome content\n** Sub\nmore stuff\n"))
    (goto-char (point-max))
    (should (string= (ob-llm-get-heading-context (org-element-at-point))
                     "* Another headline\n HERE"))))
