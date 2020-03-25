;;; ox-jnb.el --- Jupyter Notebook exporter

;; Copyright (C) 2019 Brandon T. Willard

;; Author: Brandon T. Willard
;; Keywords: org, jupyter
;; Package-Version: 20191016.0000

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This library provides an exporter for Jupyter Notebook

;;; Code:
(require 'cl-lib)
(require 'ox)
(require 'ox-gfm)
(require 'ox-publish)


;;; User-Configurable Variables

(defgroup org-export-jnb nil
  "Options specific to Jupyter Notebook export back-end."
  :tag "Org Jupyter Notebook"
  :group 'org-export
  :version "24.4"
  :package-version '(Org . "8.0"))



;;; Define Back-End
(defun org-jnb-insert-cell-headings (backend)
  (when (eq backend 'jnb)
    (org-block-map
     (lambda ()
       ;; TODO: Check if immediate parent is already a Jupyter cell
       ;; TODO: Should use a gensym to identify heading cells by their names.

       ;; TODO: We need to do this before heading lines, as well!
       (save-mark-and-excursion
         (insert "jupyter-cell\n")
         (previous-line)
         (org-insert-heading nil nil t)
         (org-set-property "cell-type" "code")

         (org-insert-heading-after-current)
         (insert "jupyter-cell\n")
         (org-set-property "cell-type" "markdown")
         (org-next-visible-heading 1)
         (org-demote-subtree))

       ))))

(add-hook 'org-export-before-parsing-hook #'org-jnb-insert-cell-headings)

(org-export-define-derived-backend 'jnb 'gfm
  :filters-alist '((:filter-inline-src-block org-jnb-filter-inline-src-block)
                   (:filter-src-block org-jnb-filter-src-block)
                   ;; (:filter-parse-tree . org-jnb-separate-elements)
                   )
  :menu-entry
  '(?g "Export to Jupyter Notebook"
       ((?G "To temporary buffer"
            (lambda (a s v b) (org-jnb-export-as-notebook a s v)))
        (?g "To file" (lambda (a s v b) (org-jnb-export-to-notebook a s v)))
        (?o "To file and open"
            (lambda (a s v b)
              (if a (org-jnb-export-to-notebook t s v)
                (org-open-file (org-jnb-export-to-notebook nil s v)))))))
  :translate-alist '((src-block . org-jnb-src-block)
                     (headline . org-md-headline)
                     ;; (section . org-md-section)
                     (template . org-jnb-template)))


;;; Filters

(defun org-jnb-filter-inline-src-block (data backend info)
  data)

(defun org-jnb-filter-src-block (data backend info)
  data)

(defun org-jnb-separate-elements (tree backend info)
  "Create first-level headings that will correspond to cells in a Jupyter Notebook."
  ;; https://orgmode.org/worg/dev/org-element-api.html
  (org-element-map
      tree
      ;; (org-element-parse-buffer)
      'src-block
      ;; (remq 'item org-element-all-elements)
    (lambda (e)
      ;; TODO: Split code blocks into their own sections (at top level?).
      ;; Looks like we'll need to use `org-element-adopt-elements'
      ;; Also, we should only do this for source blocks that are evaluated.

      ;; (print "-----------")
      ;; (print (org-element-property :name e))
      ;; (print (seq-length (org-export-get-next-element e info t)))
      ;; (print "-----------")

      (let* ((new-code-section (org-element-create 'section))
             (new-code-headline (org-element-create 'headline
                                                   '(:level 1 :tags (code-cell))))
             (next-element (org-export-get-next-element e info))
             ;; (new-following-section (if ))
             )
        (org-element-adopt-elements new-code-section (org-element-copy e))
        (org-element-insert-before new-code-section e)
        ;; TODO: Insert a follow-up heading that for the elements after this code block.
        ;; We will need to determine the code type for the follow-up heading
        ;; (e.g. if the next block is a [section/]src-block).
        ;; org-export-get-parent-headline
        )

      ;; An example:
      ;; (org-element-put-property
      ;;  e :post-blank
      ;;  (if (and (eq (org-element-type e) 'paragraph)
		  ;;           (eq (org-element-type (org-element-property :parent e)) 'item)
		  ;;           (org-export-first-sibling-p e info)
		  ;;           (let ((next (org-export-get-next-element e info)))
		  ;;             (and (eq (org-element-type next) 'plain-list)
		  ;;                  (not (org-export-get-next-element next info)))))
	    ;;      0
	    ;;    1))
      )
    info)
  tree)


;;; Translators

(defun org-jnb-template (contents info)
  ;; Top-level Structure
  ;; {
  ;;   "metadata" : {
  ;;     "kernel_info": {
  ;;         # if kernel_info is defined, its name field is required.
  ;;         "name" : "the name of the kernel"
  ;;     },
  ;;     "language_info": {
  ;;         # if language_info is defined, its name field is required.
  ;;         "name" : "the programming language of the kernel",
  ;;         "version": "the version of the language",
  ;;         "codemirror_mode": "The name of the codemirror mode to use [optional]"
  ;;     }
  ;;   },
  ;;   "nbformat": 4,
  ;;   "nbformat_minor": 0,
  ;;   "cells" : [
  ;;       # list of cell dictionaries, see below
  ;;   ],
  ;; }

  ;; TODO: contents should be the string list of cells?
  ;; We could also use `(plist-get info :parse-tree)'
  (json-encode-alist
   `((metadata . ((kernel_info . nil)
                  (language_info . ((name . nil)
                                    (version . nil)
                                    (codemirror_mode . nil)))))
     (nbformat . 4)
     (nbformat_minor . 0)
     (cells . [,(json-read-from-string contents)]))))

;; Markdown Cells
;; {
;;   "cell_type" : "markdown",
;;   "metadata" : {},
;;   "source" : "[multi-line *markdown*]",
;; }
;; These can have attachments
;; {
;;   "cell_type" : "markdown",
;;   "metadata" : {},
;;   "source" : ["Here is an *inline* image ![inline image](attachment:test.png)"],
;;   "attachments" : {
;;     "test.png": {
;;         "image/png" : "base64-encoded-png-data"
;;     }
;;   }
;; }
(defun org-jnb-headline (headline contents info)
  ;; org-export-low-level-p
  (let* ((cell-type (cond
                     ((memq 'code-cell (org-export-get-tags headline info))
                      'code)
                     (t 'markdown)))
         (cell-content (if (eq cell-type 'markdown)
                           contents
                         (org-md-headline headline contents info))))
    (json-encode-alist
     `((cell_type . ,cell-type)))))

(defun org-jnb-src-block (src-block contents info)
  (let* ((lang (org-element-property :language src-block))
         (code (org-export-format-code-default src-block info))
         ;; (name (org-element-property :name src-block))
         (link-id (org-export-get-reference src-block info)))
    ;; Code Cells
    ;; {
    ;;   "cell_type" : "code",
    ;;   "execution_count": 1, # integer or null
    ;;   "metadata" : {
    ;;       "collapsed" : True, # whether the output of the cell is collapsed
    ;;       "scrolled": False, # any of true, false or "auto"
    ;;   },
    ;;   "source" : "[some multi-line code]",
    ;;   "outputs": [{
    ;;       # list of output dicts (described below)
    ;;       "output_type": "stream",
    ;;       ...
    ;;   }],
    ;; }
    (json-encode-alist
     `((cell_type . code)
       (execution_count . nil)
       (metadata . nil)
       (source . ,code)
       (outputs . [])))
    ;; TODO:
    ;; Output Types
    ;; {
    ;;   "output_type" : "stream",
    ;;   "name" : "stdout", # or stderr
    ;;   "text" : "[multiline stream text]",
    ;; }
    ;; {
    ;;   "output_type" : "display_data",
    ;;   "data" : {
    ;;     "text/plain" : "[multiline text data]",
    ;;     "image/png": "[base64-encoded-multiline-png-data]",
    ;;     "application/json": {
    ;;       # JSON data is included as-is
    ;;       "json": "data",
    ;;     },
    ;;   },
    ;;   "metadata" : {
    ;;     "image/png": {
    ;;       "width": 640,
    ;;       "height": 480,
    ;;     },
    ;;   },
    ;; }
    ;; {
    ;;   "output_type" : "execute_result",
    ;;   "execution_count": 42,
    ;;   "data" : {
    ;;     "text/plain" : "[multiline text data]",
    ;;     "image/png": "[base64-encoded-multiline-png-data]",
    ;;     "application/json": {
    ;;       # JSON data is included as-is
    ;;       "json": "data",
    ;;     },
    ;;   },
    ;;   "metadata" : {
    ;;     "image/png": {
    ;;       "width": 640,
    ;;       "height": 480,
    ;;     },
    ;;   },
    ;; }
    ;; {
    ;;   'output_type': 'error',
    ;;   'ename' : str,   # Exception name, as a string
    ;;   'evalue' : str,  # Exception value, as a string
    ;;
    ;;   # The traceback will contain a list of frames,
    ;;   # represented each as a string.
    ;;   'traceback' : list,
    ;; }
    ))


;;; Interactive functions


;;;###autoload
(defun org-jnb-export-as-notebook (&optional async subtreep visible-only)
  "Export current buffer to a Jupyter Notebook buffer.

If narrowing is active in the current buffer, only export its
narrowed part.

If a region is active, export that region.

A non-nil optional argument ASYNC means the process should happen
asynchronously.  The resulting buffer should be accessible
through the `org-export-stack' interface.

When optional argument SUBTREEP is non-nil, export the sub-tree
at point, extracting information from the headline properties
first.

When optional argument VISIBLE-ONLY is non-nil, don't export
contents of hidden elements.

Export is done in a buffer named \"*Org Jupyter Notebook Export*\", which will
be displayed when `org-export-show-temporary-export-buffer' is
non-nil."
  (interactive)
  (org-export-to-buffer 'jnb "*Org Jupyter Notebook Export*"
    ;; TODO: Check for a Jupyter Notebook mode.
    async subtreep visible-only nil nil
    (lambda () (json-mode))))

;;;###autoload
(defun org-jnb-export-to-notebook (&optional async subtreep visible-only)
  "Export current buffer to a Jupyter Notebook file.

If narrowing is active in the current buffer, only export its
narrowed part.

If a region is active, export that region.

A non-nil optional argument ASYNC means the process should happen
asynchronously.  The resulting file should be accessible through
the `org-export-stack' interface.

When optional argument SUBTREEP is non-nil, export the sub-tree
at point, extracting information from the headline properties
first.

When optional argument VISIBLE-ONLY is non-nil, don't export
contents of hidden elements.

Return output file's name."
  (interactive)
  (let ((outfile (org-export-output-file-name ".ipynb" subtreep)))
    (org-export-to-file 'jnb outfile async subtreep visible-only)))

;;;###autoload
(defun org-jnb-publish-to-notebook (plist filename pub-dir)
  "Publish an org file to Jupyter Notebook.
FILENAME is the filename of the Org file to be published.  PLIST
is the property list for the given project.  PUB-DIR is the
publishing directory.
Return output file name."
  (org-publish-org-to 'jnb filename ".ipynb" plist pub-dir))

;; NOTES: We could use `org-export-data-with-backend' to pre-convert
;; sections to Markdown.
;; FYI: I think `ox-freemind' does a lot of things we might want to do.


(provide 'ox-jnb)
;;; ox-jnb.el ends here
