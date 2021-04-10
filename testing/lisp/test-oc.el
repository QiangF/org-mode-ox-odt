;;; test-oc.el --- Tests for Org Cite library        -*- lexical-binding: t; -*-

;; Copyright (C) 2021  Nicolas Goaziou

;; Author: Nicolas Goaziou <mail@nicolasgoaziou.fr>

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Code:

(require 'oc)
(require 'ox)
;; We need `org-test-with-parsed-data' macro.
(require 'test-ox "../testing/lisp/test-ox.el")

(ert-deftest test-org-cite/register-processor ()
  "Test `org-cite-register-processor'."
  ;; Default test.
  (should
   (let ((org-cite--processors nil))
     (org-cite-register-processor 'name)))
  ;; Invalid name type.
  (should-error (org-cite-register-processor "name"))
  ;; Duplicate processor.
  (should-error
   (let ((org-cite--processors nil))
     (org-cite-register-processor 'name)
     (org-cite-register-processor 'name)))
  ;; Unknown property.
  (should-error
   (let ((org-cite--processors nil))
     (org-cite-register-processor :foo 'bar))))

(ert-deftest test-org-cite/unregister-processor ()
  "Test `org-cite-unregister-processor'."
  ;; Default test.
  (should-not
   (let ((org-cite--processors nil))
     (org-cite-register-processor 'name)
     (org-cite-unregister-processor 'name)
     org-cite--processors))
  ;; Error out with an unknown processor.
  (should-error
   (let ((org-cite--processors nil))
     (org-cite-unregister-processor 'name))))

(ert-deftest test-org-cite/inside-footnote-p ()
  "Test `org-cite-inside-footnote-p'."
  (should
   (org-test-with-temp-text "[fn:1] <point>[cite:@key]"
     (org-cite-inside-footnote-p (org-element-context))))
  (should
   (org-test-with-temp-text "[fn::<point>[cite:@key]]"
     (org-cite-inside-footnote-p (org-element-context))))
  (should-not
   (org-test-with-temp-text "[cite:@key]"
     (org-cite-inside-footnote-p (org-element-context)))))

(ert-deftest test-org-cite/processor-has-capability-p ()
  "Test `org-cite-processor-has-capability-p'."
  ;; Unknown capability error.
  (should-error
   (let ((org-cite--processors nil))
     (org-cite-register-processor 'name :activate #'ignore)
     (org-cite-processor-has-capability-p 'name 'unknown)))
  ;; Test `activate' capability.
  (should
   (let ((org-cite--processors nil))
     (org-cite-register-processor 'name :activate #'ignore)
     (org-cite-processor-has-capability-p 'name 'activate)))
  (should-not
   (let ((org-cite--processors nil))
     (org-cite-register-processor 'name :follow #'ignore)
     (org-cite-processor-has-capability-p 'name 'activate)))
  ;; Test `export' capability.
  (should
   (let ((org-cite--processors nil))
     (org-cite-register-processor 'name
       :export-bibliography #'ignore
       :export-citation #'ignore)
     (org-cite-processor-has-capability-p 'name 'export)))
  (should
   (let ((org-cite--processors nil))
     (org-cite-register-processor 'name :export-citation #'ignore)
     (org-cite-processor-has-capability-p 'name 'export)))
  (should-not
   (let ((org-cite--processors nil))
     (org-cite-register-processor 'name :export-bibliography #'ignore)
     (org-cite-processor-has-capability-p 'name 'export)))
  ;; Test `follow' capability.
  (should
   (let ((org-cite--processors nil))
     (org-cite-register-processor 'name :follow #'ignore)
     (org-cite-processor-has-capability-p 'name 'follow)))
  (should-not
   (let ((org-cite--processors nil))
     (org-cite-register-processor 'name :activate #'ignore)
     (org-cite-processor-has-capability-p 'name 'follow)))
  ;; Unknown processors have no capabilities.
  (should-not (org-cite-processor-has-capability-p 'foo 'activate))
  (should-not (org-cite-processor-has-capability-p 'foo 'export))
  (should-not (org-cite-processor-has-capability-p 'foo 'follow)))

(ert-deftest test-org-cite/get-references ()
  "Test `org-cite-get-references'."
  ;; Return a list of citation reference objects.
  (should
   (equal '(citation-reference)
          (org-test-with-temp-text "[cite:@a]"
            (mapcar #'org-element-type
                    (org-cite-get-references (org-element-context))))))
  (should
   (equal '("a")
          (org-test-with-temp-text "[cite:@a]"
            (mapcar (lambda (r) (org-element-property :key r))
                    (org-cite-get-references (org-element-context))))))
  ;; Preserve order of references.
  (should
   (equal '("a" "b")
          (org-test-with-temp-text "[cite:@a;@b]"
            (mapcar (lambda (r) (org-element-property :key r))
                    (org-cite-get-references (org-element-context))))))
  ;; Parse prefix and suffix.
  (should
   (equal '("a" "b")
          (org-test-with-temp-text "[cite:prefix @a suffix;@b]"
            (mapcar (lambda (r) (org-element-property :key r))
                    (org-cite-get-references (org-element-context))))))
  (should
   (equal '(("prefix ") nil)
          (org-test-with-temp-text "[cite:prefix @a suffix;@b]"
            (mapcar (lambda (r) (org-element-property :prefix r))
                    (org-cite-get-references (org-element-context))))))
  (should
   (equal '((" suffix") nil)
          (org-test-with-temp-text "[cite:prefix @a suffix;@b]"
            (mapcar (lambda (r) (org-element-property :suffix r))
                    (org-cite-get-references (org-element-context))))))
  ;; Ignore common prefix and suffix.
  (should
   (equal '("a")
          (org-test-with-temp-text "[cite:common prefix; @a ; common suffix]"
            (mapcar (lambda (r) (org-element-property :key r))
                    (org-cite-get-references (org-element-context))))))
  ;; Preserve buffer positions.
  (should
   (org-test-with-temp-text "[cite:@a] [cite<point>:@b]"
     (= (1+ (point))
        (org-element-property :begin
                              (car (org-cite-get-references (org-element-context)))))))
  ;; Handle citation from a full parse tree.
  (should
   (equal '(1 2)
          (org-test-with-temp-text "[cite:@a] [cite:@a;@b]"
            (org-element-map (org-element-parse-buffer) 'citation
              (lambda (c) (length (org-cite-get-references c))))))))

(ert-deftest test-org-cite/key-boundaries ()
  "Test `org-cite-key-boundaries'."
  (should
   (equal "@key"
          (org-test-with-temp-text "[cite:<point>@key]"
            (let ((boundaries (org-cite-key-boundaries (org-element-context))))
              (buffer-substring-no-properties
               (car boundaries)
               (cdr boundaries))))))
  (should
   (equal "@key"
          (org-test-with-temp-text "[cite:<point>prefix @key]"
            (let ((boundaries (org-cite-key-boundaries (org-element-context))))
              (buffer-substring-no-properties
               (car boundaries)
               (cdr boundaries))))))
  (should
   (equal "@key"
          (org-test-with-temp-text "[cite:<point>@key suffix]"
            (let ((boundaries (org-cite-key-boundaries (org-element-context))))
              (buffer-substring-no-properties
               (car boundaries)
               (cdr boundaries))))))
  (should
   (equal "@key"
          (org-test-with-temp-text "[cite:global ;<point>@key]"
            (let ((boundaries (org-cite-key-boundaries (org-element-context))))
              (buffer-substring-no-properties
               (car boundaries)
               (cdr boundaries))))))
  (should
   (equal "@key"
          (org-test-with-temp-text "[cite:<point>@key; global]"
            (let ((boundaries (org-cite-key-boundaries (org-element-context))))
              (buffer-substring-no-properties
               (car boundaries)
               (cdr boundaries)))))))

(ert-deftest test-org-cite/list-bibliography-files ()
  "Test `org-cite-list-bibliography-files'."
  (should
   (equal '("/bibliography")
          (org-test-with-temp-text "#+bibliography: /bibliography"
            (let ((org-cite-global-bibliography nil))
              (org-cite-list-bibliography-files)))))
  (should
   (equal '("/bibliography")
          (org-test-with-temp-text "#+bibliography: \"/bibliography\""
            (let ((org-cite-global-bibliography nil))
              (org-cite-list-bibliography-files)))))
  (should
   (equal '("/bibliography" "/other-bibliography")
          (org-test-with-temp-text "#+bibliography: /bibliography"
            (let ((org-cite-global-bibliography '("/other-bibliography")))
              (org-cite-list-bibliography-files)))))
  (should
   (equal '(t)
          (org-test-with-temp-text "#+bibliography: ./bibliography"
            (let ((org-cite-global-bibliography nil))
              (mapcar #'file-name-absolute-p (org-cite-list-bibliography-files))))))
  (should
   (equal '("/bibliographyA" "/bibliographyB")
          (org-test-with-temp-text
              "#+bibliography: /bibliographyA\n#+bibliography: /bibliographyB"
            (let ((org-cite-global-bibliography nil))
              (org-cite-list-bibliography-files)))))
  (should
   (equal '("/bibliographyA")
          (org-test-with-temp-text
              "#+bibliography: /bibliographyA\n#+bibliography: /bibliographyA"
            (let ((org-cite-global-bibliography nil))
              (org-cite-list-bibliography-files))))))

(ert-deftest test-org-cite/bibliography-style ()
  "Test `org-cite-bibliography-style'."
  ;; Extract style from global processor definition.
  (should
   (equal "a"
          (catch :exit
            (org-test-with-temp-text "#+print_bibliography:"
              (let ((org-cite-export-processor '(foo "a" "b"))
                    (org-cite--processors nil))
                (org-cite-register-processor 'foo
                  :export-bibliography (lambda (_ _ s _ _ _) (throw :exit s))
                  :export-citation #'ignore)
                (org-export-as (org-export-create-backend)))))))
  ;; Extract style from local processor definition.
  (should
   (equal "a"
          (catch :exit
            (org-test-with-temp-text
                "#+cite_export: foo a b\n#+print_bibliography:"
              (let ((org-cite-export-processor nil)
                    (org-cite--processors nil))
                (org-cite-register-processor 'foo
                  :export-bibliography (lambda (_ _ s _ _ _) (throw :exit s))
                  :export-citation #'ignore)
                (org-export-as (org-export-create-backend)))))))
  ;; Test priority: first keyword, then local.
  (should
   (equal "local"
          (catch :exit
            (org-test-with-temp-text
                "#+print_bibliography:\n#+cite_export: foo local a\n[cite:@a]"
              (let ((org-cite-export-processor '(foo "global" "b"))
                    (org-cite--processors nil))
                (org-cite-register-processor 'foo
                  :export-bibliography (lambda (_ _ s _ _ _) (throw :exit s))
                  :export-citation #'ignore)
                (org-export-as (org-export-create-backend)))))))
  ;; Explicit "nil" styles forces default style.
  (should-not
   (catch :exit
     (org-test-with-temp-text
         "#+print_bibliography:\n#+cite_export: foo nil a\n[cite:@a]"
       (let ((org-cite-export-processor '(foo "global" "b"))
             (org-cite--processors nil))
         (org-cite-register-processor 'foo
           :export-bibliography (lambda (_ _ s _ _ _) (throw :exit s))
           :export-citation #'ignore)
         (org-export-as (org-export-create-backend)))))))

(ert-deftest test-org-cite/bibliography-properties ()
  "Test `org-cite-bibliography-properties'."
  ;; Return nil without properties.
  (should-not
   (org-test-with-parsed-data "#+print_bibliography:"
     (org-element-map tree 'keyword
       #'org-cite-bibliography-properties info t)))
  ;; Regular tests.
  (should
   (equal
    '(:key "value")
    (org-test-with-parsed-data "#+print_bibliography: :key value"
      (org-element-map tree 'keyword
        #'org-cite-bibliography-properties info t))))
  (should
   (equal
    '(:key "value" :key2 "value2")
    (org-test-with-parsed-data "#+print_bibliography: :key value :key2 value2"
      (org-element-map tree 'keyword
        #'org-cite-bibliography-properties info t))))
  ;; Allow empty values.
  (should
   (equal
    '(:key)
    (org-test-with-parsed-data "#+print_bibliography: :key"
      (org-element-map tree 'keyword
        #'org-cite-bibliography-properties info t))))
  (should
   (equal
    '(:key "")
    (org-test-with-parsed-data "#+print_bibliography: :key \"\""
      (org-element-map tree 'keyword
        #'org-cite-bibliography-properties info t))))
  ;; Allow space with double quotes.
  (should
   (equal
    '(:key "space space")
    (org-test-with-parsed-data "#+print_bibliography: :key \"space space\""
      (org-element-map tree 'keyword
        #'org-cite-bibliography-properties info t))))
  ;; Ignore spurious values.
  (should
   (equal
    '(:key "space")
    (org-test-with-parsed-data "#+print_bibliography: :key space space"
      (org-element-map tree 'keyword
        #'org-cite-bibliography-properties info t))))
  ;; Gracefully handle incomplete quotations.
  (should
   (equal
    '(:key "\"space" :key2 "value2")
    (org-test-with-parsed-data "#+print_bibliography: :key \"space :key2 value2"
      (org-element-map tree 'keyword
        #'org-cite-bibliography-properties info t)))))

(ert-deftest test-org-cite/citation-style ()
  "Test `org-cite-citation-style'."
  ;; Extract style from global processor definition.
  (should
   (equal '("b")
          (catch :exit
            (org-test-with-temp-text "[cite:@a]"
              (let ((org-cite-export-processor '(foo "a" "b"))
                    (org-cite--processors nil))
                (org-cite-register-processor 'foo
                  :export-citation (lambda (_ s _ _) (throw :exit s)))
                (org-export-as (org-export-create-backend)))))))
  (should
   (equal '("b" . "variant")
          (catch :exit
            (org-test-with-temp-text "[cite:@a]"
              (let ((org-cite-export-processor '(foo "a" "b/variant"))
                    (org-cite--processors nil))
                (org-cite-register-processor 'foo
                  :export-citation (lambda (_ s _ _) (throw :exit s)))
                (org-export-as (org-export-create-backend)))))))
  ;; Extract style from local processor definition.
  (should
   (equal '("b")
          (catch :exit
            (org-test-with-temp-text "#+cite_export: foo a b\n[cite:@a]"
              (let ((org-cite-export-processor nil)
                    (org-cite--processors nil))
                (org-cite-register-processor 'foo
                  :export-citation (lambda (_ s _ _) (throw :exit s)))
                (org-export-as (org-export-create-backend)))))))
  (should
   (equal '("b" . "variant")
          (catch :exit
            (org-test-with-temp-text "#+cite_export: foo a b/variant\n[cite:@a]"
              (let ((org-cite-export-processor nil)
                    (org-cite--processors nil))
                (org-cite-register-processor 'foo
                  :export-citation (lambda (_ s _ _) (throw :exit s)))
                (org-export-as (org-export-create-backend)))))))
  ;; Extract style from citation itself.
  (should
   (equal '("b")
          (catch :exit
            (org-test-with-temp-text "[cite/b:@a]"
              (let ((org-cite-export-processor '(foo nil nil))
                    (org-cite--processors nil))
                (org-cite-register-processor 'foo
                  :export-citation (lambda (_ s _ _) (throw :exit s)))
                (org-export-as (org-export-create-backend)))))))
  (should
   (equal '("b" . "variant")
          (catch :exit
            (org-test-with-temp-text "[cite/b/variant:@a]"
              (let ((org-cite-export-processor '(foo nil nil))
                    (org-cite--processors nil))
                (org-cite-register-processor 'foo
                  :export-citation (lambda (_ s _ _) (throw :exit s)))
                (org-export-as (org-export-create-backend)))))))
  ;; Test priority: first object, then local.
  (should
   (equal '("object")
          (catch :exit
            (org-test-with-temp-text
                "#+cite_export: foo nil local\n[cite/object:@a]"
              (let ((org-cite-export-processor '(foo nil "global"))
                    (org-cite--processors nil))
                (org-cite-register-processor 'foo
                  :export-citation (lambda (_ s _ _) (throw :exit s)))
                (org-export-as (org-export-create-backend)))))))
  (should
   (equal '("local")
          (catch :exit
            (org-test-with-temp-text
                "#+cite_export: foo nil local\n[cite:@a]"
              (let ((org-cite-export-processor '(foo nil "global"))
                    (org-cite--processors nil))
                (org-cite-register-processor 'foo
                  :export-citation (lambda (_ s _ _) (throw :exit s)))
                (org-export-as (org-export-create-backend)))))))
  ;; Force default style with "nil".
  (should
   (equal '(nil)
          (catch :exit
            (org-test-with-temp-text
                "#+cite_export: foo nil nil\n[cite:@a]"
              (let ((org-cite-export-processor '(foo nil "global"))
                    (org-cite--processors nil))
                (org-cite-register-processor 'foo
                  :export-citation (lambda (_ s _ _) (throw :exit s)))
                (org-export-as (org-export-create-backend)))))))
  (should
   (equal '(nil)
          (catch :exit
            (org-test-with-temp-text "[cite/nil:@a]"
              (let ((org-cite-export-processor '(foo nil "global"))
                    (org-cite--processors nil))
                (org-cite-register-processor 'foo
                  :export-citation (lambda (_ s _ _) (throw :exit s)))
                (org-export-as (org-export-create-backend)))))))
  ;; Test variant inheritance.
  (should
   (equal '("local" . "v2")
          (catch :exit
            (org-test-with-temp-text "[cite/local/v2:@a]"
              (let ((org-cite-export-processor '(foo nil "global/v1"))
                    (org-cite--processors nil))
                (org-cite-register-processor 'foo
                  :export-citation (lambda (_ s _ _) (throw :exit s)))
                (org-export-as (org-export-create-backend)))))))
  (should
   (equal '("global" . "v2")
          (catch :exit
            (org-test-with-temp-text "[cite//v2:@a]"
              (let ((org-cite-export-processor '(foo nil "global/v1"))
                    (org-cite--processors nil))
                (org-cite-register-processor 'foo
                  :export-citation (lambda (_ s _ _) (throw :exit s)))
                (org-export-as (org-export-create-backend)))))))
  (should
   (equal '(nil . "v2")
          (catch :exit
            (org-test-with-temp-text "[cite/nil/v2:@a]"
              (let ((org-cite-export-processor '(foo nil "global/v1"))
                    (org-cite--processors nil))
                (org-cite-register-processor 'foo
                  :export-citation (lambda (_ s _ _) (throw :exit s)))
                (org-export-as (org-export-create-backend)))))))
  (should
   (equal '("local" . nil)
          (catch :exit
            (org-test-with-temp-text "[cite/local:@a]"
              (let ((org-cite-export-processor '(foo nil "global/v1"))
                    (org-cite--processors nil))
                (org-cite-register-processor 'foo
                  :export-citation (lambda (_ s _ _) (throw :exit s)))
                (org-export-as (org-export-create-backend))))))))

(ert-deftest test-org-cite/list-citations ()
  "Test `org-cite-list-citations'."
  (should
   (equal '("a")
          (org-test-with-parsed-data "Test [cite:@a]"
            (cl-mapcan (lambda (c)
                         (mapcar (lambda (ref)
                                   (org-element-property :key ref))
                                 (org-element-contents c)))
                       (org-cite-list-citations info)))))
  (should
   (equal '("a" "b")
          (org-test-with-parsed-data "Test [cite:@a] [cite:@b]"
            (cl-mapcan (lambda (c)
                         (mapcar (lambda (ref)
                                   (org-element-property :key ref))
                                 (org-element-contents c)))
                       (org-cite-list-citations info)))))
  (should
   (equal '("a")
          (org-test-with-parsed-data "Test[fn:1]\n[fn:1] [cite:@a]"
            (cl-mapcan (lambda (c)
                         (mapcar (lambda (ref)
                                   (org-element-property :key ref))
                                 (org-element-contents c)))
                       (org-cite-list-citations info)))))
  (should
   (equal '("a" "b")
          (org-test-with-parsed-data "First[cite:@a] Second[fn:1]\n[fn:1] [cite:@b]"
            (cl-mapcan (lambda (c)
                         (mapcar (lambda (ref)
                                   (org-element-property :key ref))
                                 (org-element-contents c)))
                       (org-cite-list-citations info)))))
  (should
   (equal '("b" "a")
          (org-test-with-parsed-data "First[fn:1] Second[cite:@a]\n[fn:1] [cite:@b]"
            (cl-mapcan (lambda (c)
                         (mapcar (lambda (ref)
                                   (org-element-property :key ref))
                                 (org-element-contents c)))
                       (org-cite-list-citations info)))))
  (should
   (equal '("a" "b")
          (org-test-with-parsed-data
              "Text[fn:1][fn:2]\n[fn:1] [cite:@a]\n\n[fn:2] [cite:@b]"
            (cl-mapcan (lambda (c)
                         (mapcar (lambda (ref)
                                   (org-element-property :key ref))
                                 (org-element-contents c)))
                       (org-cite-list-citations info)))))
  (should
   (equal '("b" "a")
          (org-test-with-parsed-data
              "Text[fn:1]\n[fn:1] [fn:2][cite:@a]\n\n[fn:2] [cite:@b]"
            (cl-mapcan (lambda (c)
                         (mapcar (lambda (ref)
                                   (org-element-property :key ref))
                                 (org-element-contents c)))
                       (org-cite-list-citations info)))))
  (should
   (equal '("a" "b")
          (org-test-with-parsed-data
              "Text[fn:1]\n[fn:1] [cite:@a][fn:2]\n\n[fn:2] [cite:@b]"
            (cl-mapcan (lambda (c)
                         (mapcar (lambda (ref)
                                   (org-element-property :key ref))
                                 (org-element-contents c)))
                       (org-cite-list-citations info)))))
  (should
   (equal '("a")
          (org-test-with-parsed-data "Text[fn::[cite:@a]]"
            (cl-mapcan (lambda (c)
                         (mapcar (lambda (ref)
                                   (org-element-property :key ref))
                                 (org-element-contents c)))
                       (org-cite-list-citations info))))))

(ert-deftest test-org-cite/list-keys ()
  "Test `org-cite-list-keys'."
  (should
   (equal '("a")
          (org-test-with-parsed-data "Test [cite:@a]"
            (org-cite-list-keys info))))
  (should
   (equal '("a" "b")
          (org-test-with-parsed-data "Test [cite:@a] [cite:@b]"
            (org-cite-list-keys info))))
  ;; Remove duplicates.
  (should
   (equal '("a")
          (org-test-with-parsed-data "Test [cite:@a] [cite:@a]"
            (org-cite-list-keys info))))
  ;; Keys are ordered by first appearance in the document.
  (should
   (equal '("a" "b")
          (org-test-with-parsed-data "Test [cite:@a] [cite:@b] [cite:@a]"
            (org-cite-list-keys info))))
  (should
   (equal '("a" "b" "c")
          (org-test-with-parsed-data
              "Test [cite:@a][fn:1] [cite:@c] [cite:@a]\n[fn:1] [cite:@b]"
            (org-cite-list-keys info)))))

(ert-deftest test-org-cite/key-number ()
  "Test `org-cite-key-number'."
  (should
   (= 1 (org-test-with-parsed-data "[cite:@key]"
          (org-cite-key-number "key" info))))
  (should
   (equal '(1 2)
          (org-test-with-parsed-data "[cite:@key] [cite:@key2] [cite:@key]"
            (list (org-cite-key-number "key" info)
                  (org-cite-key-number "key2" info)))))
  ;; When "predicate" is nil, keys are sorted by appearance order in
  ;; the buffer.
  (should
   (equal '((1 . "a") (2 . "c") (3 . "b"))
          (org-test-with-parsed-data
              "[cite:@a][fn:1] [cite:@b]\n[fn:1] [cite:@c]"
            (sort (mapcar (lambda (key)
                            (cons (org-cite-key-number key info) key))
                          '("a" "b" "c"))
                  #'car-less-than-car))))
  (should
   (equal '((1 . "a") (2 . "b") (3 . "c"))
          (org-test-with-parsed-data
              "[cite:@a][fn:1] [cite:@b]\n[fn:1] [cite:@c]"
            (sort (mapcar (lambda (key)
                            (cons (org-cite-key-number key info #'string<) key))
                          '("a" "b" "c"))
                  #'car-less-than-car)))))

(ert-deftest test-org-cite/wrap-citation ()
  "Test `org-cite-wrap-citation'."
  ;; Reference test.
  (should
   (org-test-with-parsed-data "[cite:@key]"
     (org-element-map tree 'citation
       (lambda (c)
         (org-cite-wrap-citation c info)
         (org-cite-inside-footnote-p c))
       info)))
  ;; Created footnote is anonymous.
  (should-not
   (org-test-with-parsed-data "[cite:@key]  "
     (org-element-map tree 'citation
       (lambda (c)
         (org-cite-wrap-citation c info)
         (org-element-property :label (org-cite-inside-footnote-p c)))
       info)))
  ;; Created footnote is inline.
  (should
   (equal '(inline)
          (org-test-with-parsed-data "[cite:@key]"
            (org-element-map tree 'citation
              (lambda (c)
                (org-cite-wrap-citation c info)
                (org-element-property :type (org-cite-inside-footnote-p c)))
              info))))
  ;; Preserve `:post-blank' property.
  (should
   (equal '(2)
          (org-test-with-parsed-data "[cite:@key]  "
            (org-element-map tree 'citation
              (lambda (c)
                (org-cite-wrap-citation c info)
                (org-element-property :post-blank
                                      (org-cite-inside-footnote-p c)))
              info))))
  ;; Set `:post-blank' to 0 in the element before new footnote.
  (should-not
   (org-test-with-parsed-data "Text [cite:@key]"
     (org-element-map tree 'citation
       (lambda (c)
         (org-cite-wrap-citation c info)
         (let ((previous
                (org-export-get-previous-element
                 (org-cite-inside-footnote-p c) info)))
           (string-match (rx blank string-end) previous)))
       info)))
  (should
   (equal '(0)
          (org-test-with-parsed-data "*Text* [cite:@key]"
            (org-element-map tree 'citation
              (lambda (c)
                (org-cite-wrap-citation c info)
                (let ((previous
                       (org-export-get-previous-element
                        (org-cite-inside-footnote-p c) info)))
                  (org-element-property :post-blank previous)))
              info))))
  (should
   (equal '("Text")
          (org-test-with-parsed-data "Text [cite:@key]"
            (org-element-map tree 'citation
              (lambda (c)
                (org-cite-wrap-citation c info)
                (org-export-get-previous-element
                 (org-cite-inside-footnote-p c) info))
              info)))))

(defun test-org-cite--export-with-rule (text rule &optional punct add-space)
  "Export TEXT string using RULE for punctuation positioning.
Call `org-cite-adjust-punctuation' on each citation object with RULE, PUNCT and
ADD-SPACE arguments.  Replace citation with \"@\" character in the output."
  (org-test-with-temp-text text
    (let ((org-cite--processors nil))
      (org-cite-register-processor 'test
        :export-citation
        (lambda (citation _s _b info)
          (org-cite-adjust-punctuation citation rule info punct add-space)
          "@"))
      (let ((org-cite-export-processor '(test nil nil)))
        (org-trim
         (org-export-as
	  (org-export-create-backend
	   :transcoders
	   '((section . (lambda (_s c _i) c))
             (paragraph . (lambda (_s c _i) c))))))))))

(ert-deftest test-org-cite/adjust-punctuation ()
  "Test `org-cite-adjust-punctuation' function."
  ;; Basic tests for all rules.  In the output, @ replaces citation.
  (let ((cases '("\"[cite:@k]!"
                 ".\"[cite:@k]!"
                 "\"[cite:@k]"
                 ".\"[cite:@k]"
                 ".[cite:@k]"
                 "[cite:@k]!")))
    (should                             ;test (static inside after)
     (equal
      '(sia "@\"!" ".@\"!" "@\"" ".@\"" ".@" "!@")
      (cons 'sia
            (mapcar (lambda (c)
                      (test-org-cite--export-with-rule
                       c '(static inside after)))
                    cases))))
    (should                             ;test (static inside before)
     (equal
      '(sib "@\"!" "@.\"!" "@\"" "@.\"" "@." "@!")
      (cons 'sib
            (mapcar (lambda (c)
                      (test-org-cite--export-with-rule
                       c '(static inside before)))
                    cases))))
    (should                             ;test (static outside after)
     (equal
      '(soa "\"!@" ".\"!@" "\"@" ".\"@" ".@" "!@")
      (cons 'soa
            (mapcar (lambda (c)
                      (test-org-cite--export-with-rule
                       c '(static outside after)))
                    cases))))
    (should                             ;test (static outside before)
     (equal
      '(sob "\"@!" ".\"@!" "\"@" ".\"@" "@." "@!")
      (cons 'sob
            (mapcar (lambda (c)
                      (test-org-cite--export-with-rule
                       c '(static outside before)))
                    cases))))
    (should                             ;test (static same after)
     (equal
      '(ssa "\"!@" ".\"!@" "\"@" ".@\"" ".@" "!@")
      (cons 'ssa
            (mapcar (lambda (c)
                      (test-org-cite--export-with-rule
                       c '(static same after)))
                    cases))))
    (should                             ;test (static same before)
     (equal
      '(ssb "\"@!" ".\"@!" "\"@" "@.\"" "@." "@!")
      (cons 'ssb
            (mapcar (lambda (c)
                      (test-org-cite--export-with-rule
                       c '(static same before)))
                    cases))))
    (should                             ;test (inside inside after)
     (equal
      '(iia "!@\"" ".@\"!" "@\"" ".@\"" ".@" "!@")
      (cons 'iia
            (mapcar (lambda (c)
                      (test-org-cite--export-with-rule
                       c '(inside inside after)))
                    cases))))
    (should                             ;test (inside inside before)
     (equal
      '(iib "@!\"" "@.\"!" "@\"" "@.\"" "@." "@!")
      (cons 'iib
            (mapcar (lambda (c)
                      (test-org-cite--export-with-rule
                       c '(inside inside before)))
                    cases))))
    (should                             ;test (inside outside after)
     (equal
      '(ioa "!\"@" ".\"!@" "\"@" ".\"@" ".@" "!@")
      (cons 'ioa
            (mapcar (lambda (c)
                      (test-org-cite--export-with-rule
                       c '(inside outside after)))
                    cases))))
    (should                             ;test (inside outside before)
     (equal
      '(iob "!\"@" ".\"@!" "\"@" ".\"@" "@." "@!")
      (cons 'iob
            (mapcar (lambda (c)
                      (test-org-cite--export-with-rule
                       c '(inside outside before)))
                    cases))))
    (should                             ;test (inside same after)
     (equal
      '(isa "!@\"" ".\"!@" "\"@" ".@\"" ".@" "!@")
      (cons 'isa
            (mapcar (lambda (c)
                      (test-org-cite--export-with-rule
                       c '(inside same after)))
                    cases))))
    (should                             ;test (inside same before)
     (equal
      '(isb "@!\"" ".\"@!" "\"@" "@.\"" "@." "@!")
      (cons 'isb
            (mapcar (lambda (c)
                      (test-org-cite--export-with-rule
                       c '(inside same before)))
                    cases))))
    (should                             ;test (outside inside after)
     (equal
      '(oia "@\"!" ".@\"!" "@\"" "@\"." ".@" "!@")
      (cons 'oia
            (mapcar (lambda (c)
                      (test-org-cite--export-with-rule
                       c '(outside inside after)))
                    cases))))
    (should                             ;test (outside inside before)
     (equal
      '(oib "@\"!" "@.\"!" "@\"" "@\"." "@." "@!")
      (cons 'oib
            (mapcar (lambda (c)
                      (test-org-cite--export-with-rule
                       c '(outside inside before)))
                    cases))))
    (should                             ;test (outside outside after)
     (equal
      '(ooa "\"!@" ".\"!@" "\"@" "\".@" ".@" "!@")
      (cons 'ooa
            (mapcar (lambda (c)
                      (test-org-cite--export-with-rule
                       c '(outside outside after)))
                    cases))))
    (should                             ;test (outside outside before)
     (equal
      '(oob "\"@!" ".\"@!" "\"@" "\"@." "@." "@!")
      (cons 'oob
            (mapcar (lambda (c)
                      (test-org-cite--export-with-rule
                       c '(outside outside before)))
                    cases))))
    (should                             ;test (outside same after)
     (equal
      '(osa "\"!@" ".\"!@" "\"@" "\".@" ".@" "!@")
      (cons 'osa
            (mapcar (lambda (c)
                      (test-org-cite--export-with-rule
                       c '(outside same after)))
                    cases))))
    (should                             ;test (outside same before)
     (equal
      '(osb "\"@!" ".\"@!" "\"@" "\"@." "@." "@!")
      (cons 'osb
            (mapcar (lambda (c)
                      (test-org-cite--export-with-rule
                       c '(outside same before)))
                    cases)))))
  ;; Handle white space when inserting citation before quotation mark
  ;; or punctuation.
  (should
   (equal ",@\" next"
          (test-org-cite--export-with-rule ",\" [cite:@k] next"
                                           '(static inside after))))
  (should
   (equal "@,\" next"
          (test-org-cite--export-with-rule ",\" [cite:@k] next"
                                           '(static inside before))))
  (should
   (equal "@\"."
          (test-org-cite--export-with-rule "\" [cite:@k]."
                                           '(static inside before))))
  (should
   (equal "@\" !"
          (test-org-cite--export-with-rule "\" [cite:@k] !"
                                           '(static inside before))))
  (should
   (equal "text@ !"
          (test-org-cite--export-with-rule "text ![cite:@k]"
                                           '(static outside before))))
  ;; Preserve white space between citation and final punctuation when
  ;; moving citation past final punctuation.
  (should
   (equal "text !@"
          (test-org-cite--export-with-rule "text [cite:@k] !"
                                           '(static inside after))))
  (should
   (equal "text\n !@"
          (test-org-cite--export-with-rule "text [cite:@k]\n !"
                                           '(static inside after))))
  ;; Choose punctuation with optional argument.
  (should-not
   (equal "!@"
          (test-org-cite--export-with-rule "[cite:@k]!"
                                           '(static outside after)
                                           '("."))))
  (should
   (equal ".@"
          (test-org-cite--export-with-rule "[cite:@k]."
                                           '(static outside after)
                                           '("."))))
  ;; When citation is moved right after a quotation mark, insert
  ;; a space in-between.
  (should
   (equal "text\" @."
          (test-org-cite--export-with-rule
           "text\".[cite:@k]" '(static outside before) nil t)))
  (should
   (equal "text\" @ !"
          (test-org-cite--export-with-rule
           "text\" ![cite:@k]" '(static outside before) nil t))))

(ert-deftest test-org-cite/make-paragraph ()
  "Test `org-cite-make-paragraph' function."
  ;; Check string as argument.
  (should
   (eq 'paragraph
       (org-element-type (org-cite-make-paragraph "a"))))
  (should
   (equal '("a")
          (org-element-contents (org-cite-make-paragraph "a"))))
  ;; Check object as argument.
  (should
   (eq 'paragraph
       (org-element-type
        (org-cite-make-paragraph (org-element-create 'bold nil "b")))))
  (should
   (equal '(bold)
          (mapcar #'org-element-type
                  (org-element-contents
                   (org-cite-make-paragraph (org-element-create 'bold nil "b"))))))
  ;; Check secondary string as argument.
  (should
   (eq 'paragraph
       (org-element-type (org-cite-make-paragraph '("a")))))
  (should
   (equal '("a")
          (org-element-contents (org-cite-make-paragraph '("a")))))
  ;; Mix all types of arguments.
  (should
   (equal '(plain-text bold plain-text)
          (mapcar #'org-element-type
                  (org-element-contents
                   (org-cite-make-paragraph
                    "a" (org-element-create 'bold nil "b") '("c"))))))
  ;; Check `:parent' property.
  (should
   (eq 'paragraph
       (org-element-type
        (org-element-property
         :parent
         (car (org-element-contents (org-cite-make-paragraph "a"))))))))

(ert-deftest test-org-cite/emphasize ()
  "Test `org-cite-emphasize' function."
  ;; Raise an error if first argument has wrong type.
  (should-error (org-cite-emphasize 'code "a"))
  ;; Check string argument.
  (should (eq 'bold (org-element-type (org-cite-emphasize 'bold "a"))))
  (should (equal '("a") (org-element-contents (org-cite-emphasize 'bold "a"))))
  ;; Check object argument.
  (should
   (eq 'bold
       (org-element-type
        (org-cite-emphasize 'bold (org-element-create 'bold nil "a")))))
  (should
   (equal '(italic)
          (mapcar #'org-element-type
                  (org-element-contents
                   (org-cite-emphasize 'bold
                     (org-element-create 'italic nil "a"))))))
  ;; Check secondary string argument.
  (should (eq 'bold (org-element-type (org-cite-emphasize 'bold '("a")))))
  (should (equal '("a") (org-element-contents (org-cite-emphasize 'bold '("a")))))
  ;; Mix all types of arguments.
  (should
   (equal '(plain-text italic plain-text)
          (mapcar #'org-element-type
                  (org-element-contents
                   (org-cite-emphasize 'bold
                     "a" (org-element-create 'italic nil "b") '("c"))))))
  ;; Check `:parent' property.
  (should
   (eq 'bold
       (org-element-type
        (org-element-property
         :parent
         (car (org-element-contents (org-cite-emphasize 'bold "a"))))))))

(ert-deftest test-org-cite/concat ()
  "Test `org-cite-concat' function."
  ;; Return nil when there is no data.
  (should
   (equal "" (org-element-interpret-data (org-cite-concat))))
  ;; Concatenate strings, objects and secondary strings.
  (should
   (equal "ab"
          (org-element-interpret-data (org-cite-concat "a" "b"))))
  (should
   (equal "*a* b"
          (org-element-interpret-data
           (org-cite-concat (org-element-create 'bold nil "a") " b"))))
  (should
   (equal "*a* b"
          (org-element-interpret-data
           (org-cite-concat
            (list (org-element-create 'bold nil "a")) " b"))))
  ;; Return an error for any other object type.
  (should-error (org-cite-concat 2)))

(ert-deftest test-org-cite/mapconcat ()
  "Test `org-cite-mapconcat' function."
  (should
   (equal ""
          (org-element-interpret-data
           (org-cite-mapconcat #'identity nil ""))))
  (should
   (equal "ab"
          (org-element-interpret-data
           (org-cite-mapconcat #'identity '("a" "b") ""))))
  (should
   (equal "*a* b *c*"
          (org-element-interpret-data
           (org-cite-mapconcat
            #'identity
            (list (org-element-create 'bold nil "a")
                  (list " b " (org-element-create 'bold nil "c"))) ""))))
  (should
   (equal "*a* *b*"
          (org-element-interpret-data
           (org-cite-mapconcat
            (lambda (s) (org-element-create 'bold nil s))
            '("a" "b") " "))))
  (should
   (equal "*a* b*c*"
          (org-element-interpret-data
           (org-cite-mapconcat
            #'identity
            (list (org-element-create 'bold nil "a")
                  (list "b" (org-element-create 'bold nil "c"))) " ")))))


;;; TEST capabilities.
(ert-deftest test-org-cite/activate-capability ()
  "Test \"activate\" capability."
  ;; Standard test.
  (should
   (eq 'success
       (catch :exit
         (org-test-with-temp-text "[cite:@key]"
           (let ((org-cite--processors nil)
                 (org-cite-activate-processor 'foo))
             (org-cite-register-processor 'foo
               :activate (lambda (_) (throw :exit 'success)))
             (font-lock-ensure))))))
  ;; If there is no "follow" processor, or if processor does not
  ;; handle this capability, fall back to fontifying whole citation
  ;; with `org-cite' face and each key with `org-cite-key' face.
  (should
   (eq 'org-cite
       (org-test-with-temp-text "[cite:@key]"
         (let ((org-cite-activate-processor nil))
           (font-lock-ensure)
           (face-at-point)))))
  (should
   (eq 'org-cite-key
       (org-test-with-temp-text "[cite:@<point>key]"
         (let ((org-cite-activate-processor nil))
           (font-lock-ensure)
           (face-at-point)))))
  (should
   (eq 'org-cite
       (org-test-with-temp-text "[cite:@key]"
         (let ((org-cite--processors nil)
               (org-cite-activate-processor 'foo))
           (org-cite-register-processor 'foo)
           (font-lock-ensure)
           (face-at-point))))))

(ert-deftest test-org-cite/export-capability ()
  "Test \"export\" capability."
  ;; Export citations.
  (should
   (eq 'success
       (catch :exit
         (org-test-with-temp-text "[cite:@key]"
           (let ((org-cite--processors nil)
                 (org-cite-export-processor '(foo nil nil)))
             (org-cite-register-processor 'foo
               :export-citation (lambda (&rest _) (throw :exit 'success)))
             (org-export-as (org-export-create-backend)))))))
  (should
   (equal "citation\n"
          (org-test-with-temp-text "[cite:@key]"
            (let ((org-cite--processors nil)
                  (org-cite-export-processor '(foo nil nil)))
              (org-cite-register-processor 'foo
                :export-citation (lambda (&rest _) "citation"))
              (org-export-as (org-export-create-backend
                              :transcoders
                              '((section . (lambda (_ c _) c))
                                (paragraph . (lambda (_ c _) c)))))))))
  ;; Export bibliography.
  (should
   (eq 'success
       (catch :exit
         (org-test-with-temp-text "#+print_bibliography:"
           (let ((org-cite--processors nil)
                 (org-cite-export-processor '(foo nil nil)))
             (org-cite-register-processor 'foo
               :export-bibliography (lambda (&rest _) (throw :exit 'success))
               :export-citation #'ignore)
             (org-export-as (org-export-create-backend)))))))
  (should
   (equal "bibliography\n"
          (org-test-with-temp-text "#+print_bibliography:"
            (let ((org-cite--processors nil)
                  (org-cite-export-processor '(foo nil nil)))
              (org-cite-register-processor 'foo
                :export-bibliography (lambda (&rest _) "bibliography")
                :export-citation #'ignore)
              (org-export-as (org-export-create-backend
                              :transcoders
                              '((section . (lambda (_ c _) c))
                                (paragraph . (lambda (_ c _) c)))))))))
  (should
   (equal ""
          (org-test-with-temp-text "#+print_bibliography:"
            (let ((org-cite--processors nil)
                  (org-cite-export-processor '(foo nil nil)))
              (org-cite-register-processor 'foo
                :export-citation #'ignore)
              (org-export-as (org-export-create-backend
                              :transcoders
                              '((section . (lambda (_ c _) c))
                                (paragraph . (lambda (_ c _) c)))))))))
  ;; Test finalizer.
  (should
   (eq 'success
       (catch :exit
         (org-test-with-temp-text "[cite:@key]"
           (let ((org-cite--processors nil)
                 (org-cite-export-processor '(foo nil nil)))
             (org-cite-register-processor 'foo
               :export-citation (lambda (&rest _) "")
               :export-finalizer (lambda (&rest _) (throw :exit 'success)))
             (org-export-as (org-export-create-backend)))))))
  (should
   (equal "finalized!"
          (org-test-with-temp-text "[cite:@key]"
            (let ((org-cite--processors nil)
                  (org-cite-export-processor '(foo nil nil)))
              (org-cite-register-processor 'foo
                :export-citation #'ignore
                :export-finalizer (lambda (&rest _) "finalized!"))
              (org-export-as (org-export-create-backend))))))
  ;; Ignore citations when there is no selected "export" processor.
  ;; In that case, white space is removed before the citation, not
  ;; after.
  (should
   (equal ""
          (org-test-with-temp-text "[cite:@key]"
            (let ((org-cite-export-processor nil))
              (org-export-as (org-export-create-backend
                              :transcoders
                              '((section . (lambda (_ c _) c))
                                (paragraph . (lambda (_ c _) c)))))))))
  (should
   (equal "Text.\n"
          (org-test-with-temp-text "Text [cite:@key]."
            (let ((org-cite-export-processor nil))
              (org-export-as (org-export-create-backend
                              :transcoders
                              '((section . (lambda (_ c _) c))
                                (paragraph . (lambda (_ c _) c)))))))))
  ;; Throw an error if selected processor does not handle "export"
  ;; capability.
  (should-error
   (org-test-with-temp-text "[cite:@key]"
     (let ((org-cite--processors nil)
           (org-cite-export-processor '(foo nil nil)))
       (org-cite-register-processor 'foo)
       (org-export-as (org-export-create-backend))))))

(ert-deftest test-org-cite/follow-capability ()
  "Test \"follow\" capability."
  ;; Standard test.
  (should
   (eq 'success
       (catch :exit
         (org-test-with-temp-text "[cite:@key]"
           (let ((org-cite--processors nil)
                 (org-cite-follow-processor 'foo))
             (org-cite-register-processor 'foo
               :follow (lambda (_ _) (throw :exit 'success)))
             (org-open-at-point))))))
  ;; Throw an error if there is no "follow" processor, or if it is
  ;; unable to follow a citation.
  (should-error
   (org-test-with-temp-text "[cite:@key]"
     (let ((org-cite-follow-processor nil))
       (org-open-at-point))))
  (should-error
   (org-test-with-temp-text "[cite:@key]"
     (let ((org-cite--processors nil)
           (org-cite-follow-processor 'foo))
       (org-cite-register-processor 'foo)
       (org-open-at-point)))))

(provide 'test-oc)
;;; test-oc.el ends here
