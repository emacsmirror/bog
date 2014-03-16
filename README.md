Bog is a system for taking research notes in [Org mode](http://orgmode.org/). It adds a few
research-specific features, nearly all of which are focused on managing
and taking notes with Org, not on writing research articles with Org.

# Workflow

Many people use Org for taking research notes, and there are some really
nice descriptions of systems people have come up with (for a few
examples, see [these](http://thread.gmane.org/gmane.emacs.orgmode/78983) [threads](http://thread.gmane.org/gmane.emacs.orgmode/14756) on the Org mode mailing list).

The Bog workflow is focused around the citekey, which is the only study
information that must be included in the notes. This unique identifier
is used as a link to the BibTeX and PDF files.

In the example below, the citekey "name2000word" is a study heading. Bog
expects the citekey to be the title or property of a heading. The
citekey "another1999study" is a reference to another study (which may or
may not have a subtree in this or another Org file).

    
    * Topic heading
    
    ** TODO name2000word                               :atag:
    
    <URL for study>
    
    Article notes ... a reference to another1999study ...

The default format for the citekey is the first author's last name, the
year, and then the first non-trivial word. To have BibTeX mode
automatically generate a key of this format, the `bibtex-autokey-*`
settings can be modified.

    (setq bibtex-autokey-year-length 4
          bibtex-autokey-titleword-length nil
          bibtex-autokey-titlewords-stretch 0
          bibtex-autokey-titlewords 1
          bibtex-autokey-year-title-separator "")

# Main features

Many Bog functions take the citekey from the notes context. If the point
is on a citekey (like "another1999study" above), then that citekey will
be used. Otherwise, the citekey will be taken from the first parent
heading that is a study.
-   `bog-find-citekey-pdf`
    
    Open a PDF file for a citekey.

-   `bog-find-citekey-bib`
    
    Open a BibTeX file for a citekey.
    
    BibTeX entries can be stored in one of two ways:
    
    1.  As a single file with many entries
    2.  As single-entry files named <citekey>.bib within a common directory

-   `bog-search-citekey-on-web`
    
    Search Google Scholar for a citekey. The default citekey format (first
    author's last name, year, and first non-trivial word) usually contains
    enough information to make this search successful.

-   `bog-rename-staged-pdf-to-citekey`
    
    Rename a new PDF.

-   `bog-clean-and-rename-staged-bibs`
    
    Renaming new BibTeX files. If a separate BibTeX file is used for each
    citekey, this function can be used to rename all new BibTeX files.
    `bibtex-clean-entry` is used to clean the entry and autogenerate the
    key.

-   `bog-create-combined-bib`
    
    Generate a combined BibTeX file for all citekeys in buffer. This is
    useful if single-entry BibTeX files are used.

Other useful functions include

-   `bog-goto-citekey-heading-in-buffer`
-   `bog-goto-citekey-heading-in-notes`
-   `bog-refile`

# Variables

Several variables determine where Bog looks for things.
-   `bog-notes-directory`
-   `bog-pdf-directory`
-   `bog-bib-directory` or `bog-bib-file`
-   `bog-stage-directory`

The variables below are important for specifying how Bog behaves.

-   `bog-citekey-format`
    
    A regular expression that defines the format used for citekeys

-   `bog-citekey-function`
    
    A function to extract a citekey from the current subtree. Use this to
    indicate whether the citekey should be taken from the heading or
    property.

-   `bog-find-citekey-bib-function`
    
    A function to find a citekey in a BibTeX file. This determines whether
    a directory of single-entry BibTeX files or a single BibTeX file is
    used.

# Recommended keybindings

Bog doesn't claim any keybindings, but using "C-c b" as a prefix while
in Org mode is a good option.

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="left" />

<col  class="left" />
</colgroup>
<thead>
<tr>
<th scope="col" class="left">Key</th>
<th scope="col" class="left">Command</th>
</tr>
</thead>

<tbody>
<tr>
<td class="left">C-c b p</td>
<td class="left">`bog-find-citekey-pdf`</td>
</tr>


<tr>
<td class="left">C-c b r</td>
<td class="left">`bog-rename-staged-pdf-to-citekey`</td>
</tr>


<tr>
<td class="left">C-c b b</td>
<td class="left">`bog-find-citekey-bib`</td>
</tr>


<tr>
<td class="left">C-c b h</td>
<td class="left">`bog-goto-citekey-heading-in-buffer`</td>
</tr>


<tr>
<td class="left">C-c b H</td>
<td class="left">`bog-goto-citekey-heading-in-notes`</td>
</tr>


<tr>
<td class="left">C-c b w</td>
<td class="left">`bog-search-citekey-on-web`</td>
</tr>
</tbody>
</table>

This can be achieved by placing the code below in your .emacs file.

    (define-prefix-command 'bog-map)
    (define-key org-mode-map (kbd "C-c b") 'bog-map)
    (define-key bog-map "p" 'bog-find-citekey-pdf)
    (define-key bog-map "r" 'bog-rename-staged-pdf-to-citekey)
    (define-key bog-map "b" 'bog-find-citekey-bib)
    (define-key bog-map "h" 'bog-goto-citekey-heading-in-buffer)
    (define-key bog-map "H" 'bog-goto-citekey-heading-in-notes)
    (define-key bog-map "w" 'bog-search-citekey-on-web)