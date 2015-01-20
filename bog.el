;;; bog.el --- Extensions for research notes in Org mode

;; Copyright (C) 2013-2014 Kyle Meyer <kyle@kyleam.com>

;; Author: Kyle Meyer <kyle@kyleam.com>
;; URL: https://github.com/kyleam/bog
;; Keywords: bib, outlines
;; Version: 0.6.0
;; Package-Requires: ((dash "2.5.0"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; Bog provides a few convenience functions for taking research notes in
;; Org mode.  Many of these commands center around a citekey, the unique
;; identifier for a study.  See the README
;; (https://github.com/kyleam/bog) for more information.

;;; Code:

(require 'dash)
(require 'org)


;;; Customization

(defgroup bog nil
  "Extensions for research notes in Org mode"
  :group 'org)

(defcustom bog-citekey-format
  "\\b\\([a-z]+[-a-z]*\\)\\([0-9]\\{4\\}\\)\\([a-z][a-z0-9]*\\)\\b"
  "Regular expression used to match study citekey.

By default, this matches any sequence of lower case
letters (allowing hyphenation) that is followed by 4 digits and
then lower case letters.

The format must be anchored by '\\b' and should be restricted to
letters, digits, '-', and '_'.

This is case-sensitive (i.e., case-fold-search will be set to
nil).

The default format corresponds to the following BibTeX autokey
settings:

  (setq bibtex-autokey-year-length 4
        bibtex-autokey-titleword-length nil
        bibtex-autokey-titlewords-stretch 0
        bibtex-autokey-titlewords 1
        bibtex-autokey-year-title-separator \"\")"
  :group 'bog
  :type 'regexp)

(defcustom bog-citekey-web-search-groups '(1 2 3)
  "List of citekey subexpressions to use for web search.
The default groups correspond to the last name of the first
author, the publication year, and the first meaningful word in
the title."
  :group 'bog
  :type '(repeat integer))

(defcustom bog-citekey-property "CUSTOM_ID"
  "Property name used to store citekey.
The default corresponds to the default value of
`org-bibtex-key-property'."
  :group 'bog
  :type 'string)

(defcustom bog-root-directory "~/bib/"
  "Root directory for default values of other Bog directories."
  :group 'bog
  :type 'directory)

(defcustom bog-note-directory
  (expand-file-name "notes/" bog-root-directory)
  "Directory with Org research notes."
  :group 'bog
  :type 'directory)

(defcustom bog-file-directory
  (expand-file-name "citekey-files/" bog-root-directory)
  "Directory with citekey-associated files."
  :group 'bog
  :type 'directory)

(defcustom bog-stage-directory
  (expand-file-name "stage/" bog-root-directory)
  "Directory to search for new files.
`bog-rename-staged-file-to-citekey' and
`bog-rename-staged-bib-to-citekey' searches here for files to
rename."
  :group 'bog
  :type 'directory)

(defcustom bog-find-citekey-bib-func 'bog-find-citekey-bib-file
  "Function used to find BibTeX entry for citekey.

Default is `bog-find-citekey-bib-file', which locates single
entry BibTeX files in `bog-bib-directory'.

The other option is `bog-find-citekey-entry', which searches
within a single BibTeX file, `bog-bib-file', for the citekey
entry."
  :group 'bog
  :type 'function)

(defcustom bog-bib-directory
  (expand-file-name "bibs/" bog-root-directory)
  "The name of the directory that BibTeX files are stored in.
This is only meaningful if `bog-find-citekey-bib-func' set to
`bog-find-citekey-bib-file'."
  :group 'bog
  :type 'directory)

(defcustom bog-bib-file nil
  "BibTeX file name.
This is only meaningful if `bog-find-citekey-bib-func' set to
`bog-find-citekey-entry'."
  :group 'bog
  :type '(choice (const :tag "Don't use single file" nil)
                 (file :tag "Single file")))

(defcustom bog-citekey-file-name-separators '("-" "_")
  "Values allowed to follow the citekey in file names.
When `bog-find-citekey-file' is run on <citekey>, it will find
files with the format <citekey>.* and <citekey><sep>*.<ext>,
where <sep> is one of these characters."
  :group 'bog
  :type '(repeat string))

(defcustom bog-file-renaming-func 'bog-file-ask-on-conflict
  "Function used to rename staged files.
This function should accept a file name and a citekey as
arguments and return the name of the final file.  Currently the
only built-in function is `bog-file-ask-on-conflict'."
  :group 'bog
  :type 'function)

(defcustom bog-file-secondary-name "-supplement"
  "Modification to make to file name on renaming confict.
If <citekey>.<ext> already exists, `bog-file-ask-on-conflict'
prompts for another name.
<citekey>`bog-file-secondary-name'.<ext> is the default value for
the prompt."
  :group 'bog
  :type 'string)

(defcustom bog-web-search-url
  "http://scholar.google.com/scholar?q=%s"
  "URL to use for CITEKEY search.
It should contain the placeholder \"%s\" for the query."
  :group 'bog
  :type 'string)

(defcustom  bog-topic-heading-level 1
  "Consider headings at this level to be topic headings.
Topic headings for studies may be at any level, but
`bog-sort-topic-headings' uses this variable to determine what
level to operate on."
  :group 'bog
  :type 'integer)

(defcustom  bog-refile-maxlevel bog-topic-heading-level
  "Consider up to this level when refiling with `bog-refile'."
  :group 'bog
  :type 'integer)

(defcustom bog-keymap-prefix (kbd "C-c \"")
  "Bog keymap prefix."
  :group 'bog
  :type 'key-sequence)

(defcustom bog-use-citekey-cache nil
  "Cache list of all citekeys.
Depending on the number of citekeys present in your notes,
enabling this can make functions that prompt with a list of all
citekeys (or all heading citekeys) noticeably faster.  However,
no attempt is made to update the list of citekeys.  To see newly
added citekeys, clear the cache with `bog-clear-citekey-cache'."
  :group 'bog
  :type 'boolean)


;;; Citekey methods

(defmacro bog-selection-method (name context-method collection-method)
  "Create citekey selection function.
Create a function named bog-citekey-from-NAME with the following
behavior:
- Takes one argument (NO-CONTEXT).
- If NO-CONTEXT is nil, calls CONTEXT-METHOD with no arguments.
- If CONTEXT-METHOD returns nil or if NO-CONTEXT is non-nil,
  prompts with the citekeys gathered by COLLECTION-METHOD."
  `(defun ,(intern (concat "bog-citekey-from-" name)) (no-context)
     ,(format "Select citekey with `%s', falling back on `%s'.
If NO-CONTEXT is non-nil, immediately fall back."
              (symbol-name context-method)
              (symbol-name collection-method))
      (or (and no-context (bog-select-citekey (,collection-method)))
          (,context-method)
          (bog-select-citekey (,collection-method)))))

(bog-selection-method "surroundings-or-files"
                      bog-citekey-from-surroundings
                      bog-all-file-citekeys)

(bog-selection-method "surroundings-or-bibs"
                      bog-citekey-from-surroundings
                      bog-bib-citekeys)

(bog-selection-method "surroundings-or-all"
                      bog-citekey-from-surroundings
                      bog-all-citekeys)

(bog-selection-method "point-or-buffer-headings"
                      bog-citekey-at-point
                      bog-heading-citekeys-in-wide-buffer)

(bog-selection-method "point-or-all-headings"
                      bog-citekey-at-point
                      bog-all-heading-citekeys)

(defun bog-select-citekey (citekeys)
  "Prompt for citekey from CITEKEYS."
  (org-icompleting-read "Select citekey: " citekeys))

(defmacro bog--with-citekey-syntax (&rest body)
  "Execute BODY with hyphen and underscore as word constituents."
  (declare (indent 0))
  `(with-syntax-table (copy-syntax-table (syntax-table))
     (modify-syntax-entry ?- "w")
     (modify-syntax-entry ?_ "w")
     ,@body))

(defun bog-citekey-at-point ()
  "Return citekey at point.
The citekey must have the format specified by
`bog-citekey-format'.  Hyphens and underscores are considered as
word constituents."
  (save-excursion
    (bog--with-citekey-syntax
      (skip-syntax-backward "w")
      (let (case-fold-search)
        (and (looking-at bog-citekey-format)
             (match-string-no-properties 0))))))

(defun bog-citekey-from-surroundings ()
  "Get the citekey from the context of the Org file."
  (or (bog-citekey-at-point)
      (bog-citekey-from-tree)))

(defun bog-citekey-from-tree ()
  "Retrieve citekey from first parent heading associated with citekey."
  (org-with-wide-buffer
   (let (maybe-citekey)
     (while (and (not (setq maybe-citekey (bog-citekey-from-heading)))
                 ;; This isn't actually safe in Org mode <= 8.2.10.
                 ;; Fixed in Org mode commit
                 ;; 9ba9f916e87297d863c197cb87199adbb39da894.
                 (ignore-errors (org-up-heading-safe))))
     maybe-citekey)))

(defun bog-citekey-from-heading ()
  "Retrieve citekey from current heading title or property."
  (or (bog-citekey-from-heading-title)
      (bog-citekey-from-property)))

(defun bog-citekey-from-heading-title ()
  "Retrieve citekey from heading title."
  (unless (org-before-first-heading-p)
    (let ((heading (org-no-properties (org-get-heading t t))))
      (and (bog-citekey-p heading)
           heading))))

(defun bog-citekey-from-property ()
  "Retrieve citekey from `bog-citekey-property'."
  (--when-let (org-entry-get (point) bog-citekey-property)
    (and (bog-citekey-p it)
         it)))

(defun bog-citekey-p (text)
  "Return non-nil if TEXT matches `bog-citekey-format'."
  (let (case-fold-search)
    (string-match-p (format "^%s$" bog-citekey-format) text)))

(defvar bog--all-citekeys nil)
(defun bog-all-citekeys ()
  "Return all citekeys in notes."
  (or (and bog-use-citekey-cache bog--all-citekeys)
      (setq bog--all-citekeys (-mapcat #'bog-citekeys-in-file
                                       (bog-notes)))))

(defvar bog--all-heading-citekeys nil)
(defun bog-all-heading-citekeys ()
  "Return citekeys that have a heading in any note file."
  (or (and bog-use-citekey-cache bog--all-heading-citekeys)
      (setq bog--all-heading-citekeys (-mapcat 'bog-heading-citekeys-in-file
                                               (bog-notes)))))

(defun bog-clear-citekey-cache ()
  "Clear cache of citekeys contained in notes."
  (interactive)
  (setq bog--all-citekeys nil
        bog--all-heading-citekeys nil))

(defun bog-citekeys-in-file (file)
  "Return all citekeys in FILE."
  (with-temp-buffer
    (insert-file-contents file)
    (bog-citekeys-in-buffer)))

(defun bog-citekeys-in-buffer ()
  "Return all citekeys in current buffer."
  (save-excursion
    (let (citekeys
          case-fold-search)
      (goto-char (point-min))
      (while (re-search-forward bog-citekey-format nil t)
        (push (match-string-no-properties 0) citekeys))
      (-distinct citekeys))))

(defun bog-heading-citekeys-in-file (file)
  "Return all citekeys in headings of FILE."
  (with-temp-buffer
    (org-mode)
    (insert-file-contents file)
    (bog-heading-citekeys-in-buffer)))

(defun bog-heading-citekeys-in-buffer ()
  "Return all heading citekeys in current buffer."
  (--keep it
          (org-map-entries 'bog-citekey-from-heading)))

(defun bog-heading-citekeys-in-wide-buffer ()
  "Return all citekeys in current buffer, without any narrowing."
  (--keep it
          (org-map-entries 'bog-citekey-from-heading nil 'file)))

(defun bog-non-heading-citekeys-in-file (file)
  "Return all non-heading citekeys in FILE."
  (let (citekeys
        case-fold-search)
    (with-temp-buffer
      (org-mode)
      (insert-file-contents file)
      (while (re-search-forward bog-citekey-format nil t)
        (unless (or (org-at-heading-p)
                    (org-at-property-p))
          (push (match-string-no-properties 0) citekeys))))
    (-distinct citekeys)))

(defun bog-list-orphan-citekeys (&optional file)
  "List in citekeys that appear in notes but don't have heading.
With prefix FILE, include only orphan citekeys from that file."
  (interactive (list (and current-prefix-arg
                          (bog-read-note-file-name))))
  (let ((files (or (and file (list file))
                   (bog-notes)))
        (heading-cks (bog-all-heading-citekeys))
        (bufname "*Bog orphan citekeys*")
        cks)
    (with-current-buffer (get-buffer-create bufname)
      (erase-buffer)
      (insert "\n")
      (-each files
        (lambda (f)
          (setq cks
                (--> (bog-non-heading-citekeys-in-file f)
                  (-difference it heading-cks)
                  (-sort (lambda (x y) (string-lessp x y)) it)
                  (mapconcat #'identity it "\n")))
          (unless (equal cks "")
            (insert (format "* %s\n\n" (file-name-nondirectory f)))
            (insert (concat cks "\n\n")))))
      (org-mode)
      (show-all)
      (goto-char (point-min)))
    (pop-to-buffer bufname)))


;;; Citekey-associated files

;;;###autoload
(defun bog-find-citekey-file (&optional no-context)
  "Open citekey-associated file.

The citekey is taken from the text under point if it matches
`bog-citekey-format' or from the current tree.

With prefix argument NO-CONTEXT, prompt with citekeys that have
an associated file in `bog-file-directory'.  Do the same if
locating a citekey from context fails."
  (interactive "P")
  (bog--find-citekey-file
   (bog-citekey-from-surroundings-or-files no-context)))

(defun bog--find-citekey-file (citekey)
  (let* (citekey-file
         (citekey-files (bog-citekey-files citekey))
         (citekey-file-names (-map 'file-name-nondirectory citekey-files))
         (num-choices (length citekey-file-names)))
    (case num-choices
      (0 (user-error "No file found for %s" citekey))
      (1 (setq citekey-file (car citekey-files)))
      (t (setq citekey-file (expand-file-name
                             (org-icompleting-read "Select file: "
                                                   citekey-file-names)
                             bog-file-directory))))
    (org-open-file citekey-file)))

(defun bog-citekey-files (citekey)
  "Return files in `bog-file-directory' associated with CITEKEY.
These should be named CITEKEY<sep>*.<ext>, where <sep> is a
character in `bog-citekey-file-name-separators'."
  (let* ((patterns (--map (concat it "*") bog-citekey-file-name-separators))
         (patterns (cons ".*" patterns)))
    (--mapcat (file-expand-wildcards
               (concat (file-name-as-directory bog-file-directory)
                       citekey it))
              patterns)))

;;;###autoload
(defun bog-rename-staged-file-to-citekey (&optional no-context)
  "Rename citekey file in `bog-stage-directory' with `bog-file-renaming-func'.

The citekey is taken from the text under point if it matches
`bog-citekey-format' or from the current tree.

With prefix argument NO-CONTEXT, prompt with citekeys present in
any note file.  Do the same if locating a citekey from context
fails.

If the citekey file prompt is slow to appear, consider enabling
`bog-use-citekey-cache'."
  (interactive "P")
  (bog--rename-staged-file-to-citekey
   (bog-citekey-from-surroundings-or-all no-context)))

(defun bog--rename-staged-file-to-citekey (citekey)
  (let* ((staged-files (bog-staged-files))
         (staged-file-names (-map 'file-name-nondirectory staged-files))
         (num-choices (length staged-file-names))
         staged-file)
    (case num-choices
      (0 (setq staged-file (org-iread-file-name "Select file to rename: ")))
      (1 (setq staged-file (car staged-files)))
      (t (setq staged-file (expand-file-name
                            (org-icompleting-read "Select file to rename: "
                                                  staged-file-names)
                            bog-stage-directory))))
    (message "Renamed %s to %s" staged-file
             (funcall bog-file-renaming-func staged-file citekey))))

(defun bog-file-ask-on-conflict (staged-file citekey)
  "Rename citekey file, prompting for a new name if it already exists.
STAGED-FILE is renamed to <citekey>.<ext> within
`bog-file-directory'.  If this file already exists, prompt for
another name.  `bog-file-secondary-name' controls the default
string for the prompt."
  (let* ((ext (file-name-extension staged-file))
         (citekey-file (bog-citekey-as-file citekey ext)))
    (condition-case nil
        (rename-file staged-file citekey-file)
      (file-error
       (let ((new-file-name
              (file-name-nondirectory
               (bog-citekey-as-file (concat citekey bog-file-secondary-name)
                                    ext))))
         (setq new-file-name
               (read-string
                (format "File %s already exists.  Name to use instead: "
                        citekey-file)
                new-file-name nil nil '(new-file-name)))
         (setq citekey-file (expand-file-name new-file-name bog-file-directory))
         (rename-file staged-file citekey-file))))
    citekey-file))

(defun bog-citekey-as-file (citekey ext)
  "Return file name `bog-file-directory'/CITEKEY.<ext>."
  (expand-file-name (concat citekey "." ext) bog-file-directory))

(defun bog-all-file-citekeys ()
  "Return a list of citekeys for files in `bog-file-directory'."
  (-distinct (-keep 'bog-file-citekey (bog-all-citekey-files))))

(defun bog-file-citekey (file)
  "Return leading citekey part from base name of FILE."
  (let ((fname (file-name-base file))
        case-fold-search)
    (and (string-match (concat "^" bog-citekey-format) fname)
         (match-string 0 fname))))

(defun bog-all-citekey-files ()
  "Return list of all files in `bog-file-directory'."
  (-remove 'file-directory-p
           (directory-files bog-file-directory
                            t directory-files-no-dot-files-regexp)))

(defun bog-staged-files ()
  "Return files in `bog-stage-directory'."
  (-remove 'file-directory-p
           (directory-files bog-stage-directory
                            t directory-files-no-dot-files-regexp)))


;;; BibTeX-related

;;;###autoload
(defun bog-find-citekey-bib (&optional no-context)
  "Open BibTeX file for a citekey.

The citekey is taken from the text under point if it matches
`bog-citekey-format' or from the current tree.

The variable `bog-find-citekey-bib-func' determines how the
citekey is found.

With prefix argument NO-CONTEXT, prompt with citekeys that have a
BibTeX entry.  Do the same if locating a citekey from context
fails."
  (interactive "P")
  (funcall bog-find-citekey-bib-func
           (bog-citekey-from-surroundings-or-bibs no-context)))

(defun bog-find-citekey-bib-file (citekey)
  "Open BibTeX file of CITEKEY contained in `bog-bib-directory'."
  (let ((bib-file (bog-citekey-as-bib citekey)))
    (unless (file-exists-p bib-file)
      (user-error "%s does not exist" bib-file))
    (find-file-other-window bib-file)))

(defun bog-find-citekey-entry (citekey)
  "Search for CITEKEY in `bog-bib-file'."
  (find-file-other-window bog-bib-file)
  (bibtex-search-entry citekey))

;;;###autoload
(defun bog-clean-and-rename-staged-bibs ()
  "Clean and rename BibTeX files in `bog-stage-directory'.

Search for new BibTeX files in `bog-stage-directory', and run
`bibtex-clean-entry' on each file before it is moved to
`bog-bib-directory'/<citekey>.bib.

This function is only useful if you use the non-standard setup of
one entry per BibTeX file."
  (interactive)
  (let ((staged
         (file-expand-wildcards
          (concat (file-name-as-directory bog-stage-directory) "*.bib"))))
    (--each staged
      (bog--prepare-bib-file it t bog-bib-directory))))

(defun bog--prepare-bib-file (file &optional new-key new-directory)
  (let (bib-file)
    (with-temp-buffer
      (bibtex-mode)
      (insert-file-contents file)
      (bibtex-skip-to-valid-entry)
      (bibtex-clean-entry new-key)
      (setq bib-file (expand-file-name (concat (bibtex-key-in-head) ".bib")
                                       new-directory))
      (write-file bib-file))
    ;; If a buffer was visiting the original bib file, point it to the
    ;; new file.
    (--when-let (find-buffer-visiting file)
      (with-current-buffer it
        (when (get-buffer bib-file)
          (user-error "Buffer for %s already exists" bib-file))
        (rename-buffer bib-file)
        (set-visited-file-name bib-file nil t)))
    (delete-file file)))

;;;###autoload
(defun bog-create-combined-bib ()
  "Create buffer that has entries for all citekeys in buffer."
  (interactive)
  (let ((bib-buffer-name "*Bog combined bib*")
        citekeys
        bib-files)
    (if (derived-mode-p 'dired-mode)
        (--each (dired-get-marked-files)
          (with-temp-buffer
            (insert-file-contents it)
            (setq citekeys (append (bog-citekeys-in-buffer) citekeys))))
      (setq citekeys (bog-citekeys-in-buffer)))
    (setq bib-files
          (-map #'bog-citekey-as-bib
                (-distinct (--sort (string-lessp it other) citekeys))))
    (with-current-buffer (get-buffer-create bib-buffer-name)
      (erase-buffer)
      (--each bib-files
        (cond
         ((file-exists-p it)
          (insert "\n")
          (insert-file-contents it)
          (goto-char (point-max)))
         ((not (y-or-n-p (format "%s does not exist.  Skip it?" it)))
          (kill-buffer bib-buffer)
          (user-error "Aborting"))))
      (bibtex-mode)
      (goto-char (point-min)))
    (pop-to-buffer bib-buffer-name)))

(defun bog-citekey-as-bib (citekey)
  "Return file name `bog-bib-directory'/CITEKEY.bib."
  (expand-file-name (concat citekey ".bib") bog-bib-directory))

(defun bog-bib-citekeys ()
  "Return a list citekeys for all BibTeX entries.
If `bog-bib-file' is non-nil, it returns citekeys from this file
instead of citekeys from file names in `bog-bib-directory'."
  (if bog-bib-file
      (with-temp-buffer
        (bibtex-mode)
        (insert-file-contents bog-bib-file)
        (-map 'car (bibtex-parse-keys)))
    (-map 'file-name-base
          (file-expand-wildcards (concat
                                  (file-name-as-directory bog-bib-directory)
                                  "*.bib")))))


;;; Web

;;;###autoload
(defun bog-search-citekey-on-web (&optional no-context)
  "Open browser and perform query based for a citekey.

Take the URL from `bog-web-search-url'.

The citekey is split by groups in `bog-citekey-format' and joined by
\"+\" to form the query string.

The citekey is taken from the text under point if it matches
`bog-citekey-format' or from the current tree.

With prefix argument NO-CONTEXT, prompt with citekeys present in
any note file.  Do the same if locating a citekey from context
fails.

If the citekey file prompt is slow to appear, consider enabling
`bog-use-citekey-cache'."
  (interactive "P")
  (bog--search-citekey-on-web
   (bog-citekey-from-surroundings-or-all no-context)))

(defun bog--search-citekey-on-web (citekey)
  (browse-url (bog-citekey-as-search-url citekey)))

(defun bog-citekey-as-search-url (citekey)
  "Return URL to use for CITEKEY search."
  (format bog-web-search-url
          (bog--citekey-groups-with-delim citekey "+")))

(defun bog--citekey-groups-with-delim (citekey delim)
  "Return expression groups CITEKEY, seperated by DELIM.
Groups are specified by `bog-citekey-web-search-groups'."
  (let (case-fold-search)
    (string-match bog-citekey-format citekey)
    (mapconcat (lambda (g) (match-string-no-properties g citekey))
               bog-citekey-web-search-groups delim)))


;;; Notes-related

(defun bog-goto-citekey-heading-in-buffer (&optional no-context)
  "Find citekey heading in this buffer.

The citekey is taken from the text under point if it matches
`bog-citekey-format'.

With prefix argument NO-CONTEXT, prompt with citekeys that have a
heading in the current buffer.  Do the same if locating a citekey
from context fails.

If the heading is found outside any current narrowing of the
buffer, the narrowing is removed."
  (interactive "P")
  (let* ((citekey (bog-citekey-from-point-or-buffer-headings no-context))
         (pos (bog--find-citekey-heading-in-buffer citekey)))
    (if pos
        (progn
         (when (or (< pos (point-min))
                   (> pos (point-max)))
           (widen))
         (org-mark-ring-push)
         (goto-char pos)
         (org-show-context))
      (message "Heading for %s not found in buffer" citekey))))

(defun bog--find-citekey-heading-in-buffer (citekey &optional pos-only)
  "Return the marker of heading for CITEKEY.
CITEKEY can either be the heading title or the property value of
the key `bog-citekey-property'.  If POS-ONLY is non-nil, return
the position instead of a marker."
  (or (org-find-exact-headline-in-buffer citekey nil pos-only)
      (bog--find-citekey-property-in-buffer citekey nil pos-only)))

(defun bog--find-citekey-property-in-buffer (citekey &optional buffer pos-only)
  "Return marker in BUFFER for heading with CITEKEY as a property value.
The property key must match `bog-citekey-property'.  If POS-ONLY
is non-nil, return the position instead of a marker."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (save-restriction
        (widen)
        (goto-char (point-min))
        (catch 'found
          (while (re-search-forward (concat "\\b" citekey "\\b") nil t)
            (save-excursion
              (beginning-of-line)
              (when (and (looking-at org-property-re)
                         (equal (downcase (match-string 2))
                                (downcase bog-citekey-property)))
                (org-back-to-heading t)
                (throw 'found
                       (if pos-only
                           (point)
                         (move-marker (make-marker) (point))))))))))))

(defun bog-goto-citekey-heading-in-notes (&optional no-context)
  "Find citekey heading in notes.

The citekey is taken from the text under point if it matches
`bog-citekey-format'.

With prefix argument NO-CONTEXT, prompt with citekeys that have a
heading in any note file.  Do the same if locating a citekey from
context fails.

If the citekey file prompt is slow to appear, consider enabling
`bog-use-citekey-cache'.

If the heading is found outside any current narrowing of the
buffer, the narrowing is removed."
  (interactive "P")
  (let* ((citekey (bog-citekey-from-point-or-all-headings no-context))
         (marker (or (and (member (buffer-file-name) (bog-notes))
                          (bog--find-citekey-heading-in-buffer citekey))
                     (bog--find-citekey-heading-in-notes citekey))))
    (if marker
        (progn
          (switch-to-buffer (marker-buffer marker))
          (when (or (< marker (point-min))
                    (> marker (point-max)))
            (widen))
          (goto-char marker)
          (org-show-context))
      (message "Heading for %s not found in notes" citekey))))

(defun bog--find-citekey-heading-in-notes (citekey)
  "Return the marker of heading for CITEKEY in notes.
CITEKEY can either be the heading title or the property value of
the key `bog-citekey-property'."
  (or (org-find-exact-heading-in-directory citekey bog-note-directory)
      (bog--find-citekey-property-in-notes citekey)))

(defun bog--find-citekey-property-in-notes (citekey)
  "Return marker within notes for heading with CITEKEY as a property value.
If the current buffer is a note file, try to find the heading
there first."
  ;; Modified from `org-find-exact-heading-in-directory'.
  (let ((files (bog-notes))
        file visiting m buffer)
    (catch 'found
      (while (setq file (pop files))
        (message "Searching properties in %s" file)
        (setq visiting (org-find-base-buffer-visiting file))
        (setq buffer (or visiting (find-file-noselect file)))
        (setq m (bog--find-citekey-property-in-buffer citekey buffer))
        (when (and (not m) (not visiting)) (kill-buffer buffer))
        (and m (throw 'found m))))))

(defun bog-citekey-tree-to-indirect-buffer (&optional no-context)
  "Open subtree for citekey in an indirect buffer.

The citekey is taken from the text under point if it matches
`bog-citekey-format'.

With prefix argument NO-CONTEXT, prompt with citekeys that have a
heading in any note file.  Do the same if locating a citekey from
context fails.

If the citekey file prompt is slow to appear, consider enabling
`bog-use-citekey-cache'."
  (interactive "P")
  (let* ((citekey (bog-citekey-from-point-or-all-headings no-context))
         (marker (bog--find-exact-heading-in-notes citekey)))
    (if marker
        (with-current-buffer (marker-buffer marker)
          (save-excursion
            (save-restriction
              (goto-char marker)
              (org-tree-to-indirect-buffer))))
      (message "Heading for %s not found in notes" citekey))))

(defun bog-refile ()
  "Refile heading within notes.
All headings from Org files in `bog-note-directory' at or above
level `bog-refile-maxlevel' are considered."
  (interactive)
  (let ((org-refile-targets `((,(bog-notes)
                               :maxlevel . ,bog-refile-maxlevel))))
    (org-refile)))

(defun bog-notes ()
  "Return Org files in `bog-note-directory'."
  (--remove (let ((base-name (file-name-nondirectory it)))
              (or (string-prefix-p "." base-name)
                  (auto-save-file-name-p base-name)))
   (file-expand-wildcards
    (concat (file-name-as-directory bog-note-directory)
            "*.org"))))

(defun bog-read-note-file-name ()
  (let ((nodir-files (-annotate #'file-name-nondirectory
                                (bog-notes))))
    (cdr (assoc (org-icompleting-read "File: "
                                      (-map #'car nodir-files))
                nodir-files))))

(defmacro bog--with-search-lprops (&rest body)
  "Execute BODY with Bog-related agenda values.
Restore the `org-lprops' property value for
`org-agenda-redo-command' after executing BODY."
  (declare (indent 0))
  `(let ((org-lprops (get 'org-agenda-redo-command 'org-lprops))
         (bog-lprops '((org-agenda-buffer-name "*Bog search*")
                       (org-agenda-files (bog-notes))
                       org-agenda-text-search-extra-files
                       org-agenda-sticky)))
     (put 'org-agenda-redo-command 'org-lprops bog-lprops)
     (org-let bog-lprops ,@body)
     (use-local-map (let ((map (make-sparse-keymap)))
                      (set-keymap-parent map org-agenda-mode-map)
                      (define-key map "r" 'bog-agenda-redo)
                      map))
     (put 'org-agenda-redo-command 'org-lprops org-lprops)))

(defun bog-search-notes (&optional todo-only string)
  "Search notes using `org-search-view'.
With prefix argument TODO-ONLY, search only TODO entries.  If
STRING is non-nil, use it as the search term (instead of
prompting for one)."
  (interactive "P")
  (bog--with-search-lprops
    '(org-search-view todo-only string)))

(defun bog-search-notes-for-citekey (&optional todo-only)
  "Search notes for citekey using `org-search-view'.

With prefix argument TODO-ONLY, search only TODO entries.

The citekey is taken from the text under point if it matches
`bog-citekey-format' or from the current tree.  If a citekey is
not found, prompt with citekeys present in any note file."
  (interactive "P")
  (bog-search-notes todo-only
                    (bog-citekey-from-surroundings-or-all nil)))

(defun bog-agenda-redo (&optional all)
  (interactive "P")
  (bog--with-search-lprops
    '(org-agenda-redo all)))

(defun bog-sort-topic-headings-in-buffer (&optional sorting-type)
  "Sort topic headings in this buffer.
SORTING-TYPE is a character passed to `org-sort-entries'.  If
nil, use ?a.  The level to sort is determined by
`bog-topic-heading-level'."
  (interactive)
  (org-map-entries (lambda () (bog-sort-if-topic-header sorting-type))))

(defun bog-sort-topic-headings-in-notes (&optional sorting-type)
  "Sort topic headings in notes.
Unlike `bog-sort-topic-headings-in-buffer', sort topic headings
in all note files."
  (interactive)
  (org-map-entries (lambda ()  (bog-sort-if-topic-header sorting-type))
                   nil (bog-notes)))

(defun bog-sort-if-topic-header (sorting-type)
  "Sort heading with `org-sort-entries' according to SORTING-TYPE.
Sorting is only done if the heading's level matches
`bog-topic-heading-level' and it isn't a citekey heading."
  (let ((sorting-type (or sorting-type ?a)))
    (when (and (= (org-current-level) bog-topic-heading-level)
               (not (bog-citekey-from-heading)))
      (org-sort-entries nil sorting-type))))

(defun bog-insert-heading-citekey (&optional current-buffer)
  "Select a citekey to insert at point.
By default, offer heading citekeys from all files.  With prefix
argument CURRENT-BUFFER, limit to heading citekeys from the
current buffer."
  (interactive "P")
  (let ((citekey-func (if current-buffer
                          'bog-heading-citekeys-in-wide-buffer
                        'bog-all-heading-citekeys)))
    (insert (bog-select-citekey (funcall citekey-func)))))

(defun bog-open-first-citekey-link (&optional no-context)
  "Open first link under citekey heading.

The citekey is taken from the text under point if it matches
`bog-citekey-format' or from the current tree.

With prefix argument NO-CONTEXT, prompt with citekeys that have a
heading in any note file.  Do the same if locating a citekey from
context fails."
  (interactive "P")
  (let* ((citekey (bog-citekey-from-point-or-all-headings no-context))
         (marker (bog--find-exact-heading-in-notes citekey)))
    (if marker
        (with-current-buffer (marker-buffer marker)
          (org-with-wide-buffer
           (goto-char marker)
           (org-narrow-to-subtree)
           (org-next-link)
           (org-open-at-point)))
      (message "Heading for %s not found in notes" citekey))))

(defun bog-next-non-heading-citekey (&optional arg)
  "Move foward to next non-heading citekey.
With argument ARG, do it ARG times."
  (interactive "p")
  (or arg (setq arg 1))
  (if (< arg 0)
      (bog-previous-non-heading-citekey (- arg))
    (bog--with-citekey-syntax
      (skip-syntax-forward "w")
      (let (case-fold-search)
        (while (and (> arg 0)
                    (re-search-forward bog-citekey-format nil t))
          (unless (org-at-heading-p)
            (setq arg (1- arg))))))
    (org-show-context)))

(defun bog-previous-non-heading-citekey (&optional arg)
  "Move backward to previous non-heading citekey.
With argument ARG, do it ARG times."
  (interactive "p")
  (or arg (setq arg 1))
  (bog--with-citekey-syntax
    (let (case-fold-search)
      (while (and (> arg 0)
                  (re-search-backward bog-citekey-format nil t))
        (unless (org-at-heading-p)
          (setq arg (1- arg)))))
    (skip-syntax-backward "w"))
  (org-show-context))


;;; Font-lock

(defface bog-citekey-face
  '((t (:inherit org-link :underline nil)))
  "Face used to highlight text that matches `bog-citekey-format'.")

(defun bog-fontify-non-heading-citekeys (limit)
  (let (case-fold-search)
    (while (re-search-forward bog-citekey-format limit t)
      (unless (save-match-data (org-at-heading-p))
        (add-text-properties (match-beginning 0) (match-end 0)
                             '(face bog-citekey-face))))))


;;; Commander

;;; The commander functionality is taken from projectile.
;;; https://github.com/bbatsov/projectile

(defconst bog-commander-help-buffer "*Commander Help*")

(defvar bog-commander-methods nil
  "List of file-selection methods for the `bog-commander' command.
Each element is a list (KEY DESCRIPTION FUNCTION).
DESCRIPTION is a one-line description of what the key selects.")

;;;###autoload
(defun bog-commander ()
  "Execute a Bog command with a single letter.

The user is prompted for a single character indicating the action
to invoke.  Press \"?\" to describe available actions.

See `def-bog-commander-method' for defining new methods."
  (interactive)
  (-let* ((choices (-map #'car bog-commander-methods))
          (prompt (concat "Commander [" choices "]: "))
          (ch (read-char-choice prompt choices))
          ((_ _ fn) (assq ch bog-commander-methods)))
    (funcall fn))  )

(defmacro def-bog-commander-method (key description &rest body)
  "Define a new `bog-commander' method.

KEY is the key the user will enter to choose this method.

DESCRIPTION is a one-line sentence describing the method.

BODY is a series of forms which are evaluated when the method is
chosen."
  (let ((method `(lambda ()
                   ,@body)))
    `(setq bog-commander-methods
           (--sort (< (car it) (car other))
                   (cons (list ,key ,description ,method)
                         (assq-delete-all ,key bog-commander-methods))))))

(def-bog-commander-method ?? "Commander help buffer."
  (ignore-errors (kill-buffer bog-commander-help-buffer))
  (with-current-buffer (get-buffer-create bog-commander-help-buffer)
    (insert "Bog commander methods:\n\n")
    (loop for (key line nil) in bog-commander-methods
          do (insert (format "%c:\t%s\n" key line)))
    (goto-char (point-min))
    (help-mode)
    (display-buffer (current-buffer) t))
  (bog-commander))

(def-bog-commander-method ?b
  "Find citekey BibTeX file."
  (bog-find-citekey-bib t))

(def-bog-commander-method ?f
  "Find citekey file."
  (bog-find-citekey-file t))

(def-bog-commander-method ?h
  "Find citekey heading in notes."
  (bog-goto-citekey-heading-in-notes t))

(def-bog-commander-method ?s
  "Search notes with `org-search-view'."
  (bog-search-notes))


;;; Minor mode

(defvar bog-mode-map
  (let ((map (make-sparse-keymap)))
    (let ((prefix-map (make-sparse-keymap)))
      (define-key prefix-map "b" 'bog-find-citekey-bib)
      (define-key prefix-map "c" 'bog-search-notes-for-citekey)
      (define-key prefix-map "f" 'bog-find-citekey-file)
      (define-key prefix-map "g" 'bog-search-citekey-on-web)
      (define-key prefix-map "h" 'bog-goto-citekey-heading-in-buffer)
      (define-key prefix-map "H" 'bog-goto-citekey-heading-in-notes)
      (define-key prefix-map "i" 'bog-citekey-tree-to-indirect-buffer)
      (define-key prefix-map "l" 'bog-open-first-citekey-link)
      (define-key prefix-map "n" 'bog-next-non-heading-citekey)
      (define-key prefix-map "p" 'bog-previous-non-heading-citekey)
      (define-key prefix-map "r" 'bog-rename-staged-file-to-citekey)
      (define-key prefix-map "s" 'bog-search-notes)
      (define-key prefix-map "w" 'bog-refile)
      (define-key prefix-map "y" 'bog-insert-heading-citekey)
      (define-key map bog-keymap-prefix prefix-map))
    map)
  "Keymap for Bog.")

;;;###autoload
(define-minor-mode bog-mode
  "Toggle Bog in this buffer.
With a prefix argument ARG, enable `bog-mode' if ARG is positive,
and disable it otherwise.  If called from Lisp, enable the mode
if ARG is omitted or nil.

\\{bog-mode-map}"
  :keymap bog-mode-map
  :group 'bog
  :lighter " Bog"
  :require 'bog
  (cond
   (bog-mode
    (add-hook 'org-font-lock-hook 'bog-fontify-non-heading-citekeys)
    (font-lock-fontify-buffer))
   (t
    (remove-hook 'org-font-lock-hook 'bog-fontify-non-heading-citekeys)
    (font-lock-fontify-buffer))))

(provide 'bog)

;;; bog.el ends here
