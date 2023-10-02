;;; symex-misc.el --- An evil way to edit Lisp symbolic expressions as trees -*- lexical-binding: t -*-

;; URL: https://github.com/drym-org/symex.el

;; This program is "part of the world," in the sense described at
;; https://drym.org.  From your perspective, this is no different than
;; MIT or BSD or other such "liberal" licenses that you may be
;; familiar with, that is to say, you are free to do whatever you like
;; with this program.  It is much more than BSD or MIT, however, in
;; that it isn't a license at all but an idea about the world and how
;; economic systems could be set up so that everyone wins.  Learn more
;; at drym.org.
;;
;; This work transcends traditional legal and economic systems, but
;; for the purposes of any such systems within which you may need to
;; operate:
;;
;; This is free and unencumbered software released into the public domain.
;; The authors relinquish any copyright claims on this work.
;;

;;; Commentary:

;; Miscellaneous Lisp editing-related features

;;; Code:


(require 'evil)
(require 'symex-primitives)
(require 'symex-evaluator)
(require 'symex-computations)
(require 'symex-traversals)
(require 'symex-interface-elisp)
(require 'symex-interface-racket)
(require 'symex-interface-scheme)
(require 'symex-interface-clojure)
(require 'symex-interface-common-lisp)
(require 'symex-interface-arc)
(require 'symex-interop)
(require 'symex-ui)

;; These are customization or config variables defined elsewhere;
;; explicitly indicating them here to avoid byte compile warnings
(defvar symex-refocus-p)
(defvar symex-highlight-p)
(defvar symex-racket-modes)
(defvar symex-elisp-modes)
(defvar symex-clojure-modes)
(defvar symex-common-lisp-modes)

;; buffer-local branch memory stack
(defvar-local symex--branch-memory nil)

;;;;;;;;;;;;;;;;;;;;;
;;; MISCELLANEOUS ;;;
;;;;;;;;;;;;;;;;;;;;;

(evil-define-state emacslike
  "An Emacs-like state."
  :tag " <E> "
  :message "-- EMACHS --"
  :enable (emacs))

(evil-define-state normallike
  "A Normal-like state."
  :tag " <N> "
  :message "-- NORMALE --"
  :enable (normal))

(defun symex--evaluate ()
  "Evaluate symex."
  (let ((original-evil-state evil-state))
    (unwind-protect
        (save-excursion
          ;; enter an "emacs-like" state so that which symex is meant
          ;; has a standard interpretation. We don't go into emacs state
          ;; itself since, as a known, "registered" evil state in
          ;; rigpa, it would trigger state transition logic
          ;; that we don't want to trigger since this is to be treated
          ;; merely as an implementation detail of this operation
          (evil-emacslike-state)
          (forward-sexp) ; selected symexes will have the cursor on the starting paren
          (cond ((member major-mode symex-racket-modes)
                 (symex-eval-racket))
                ((member major-mode symex-elisp-modes)
                 (symex-eval-elisp))
                ((equal major-mode 'scheme-mode)
                 (symex-eval-scheme))
                ((member major-mode symex-clojure-modes)
                 (symex-eval-clojure))
                ((member major-mode symex-common-lisp-modes)
                 (symex-eval-common-lisp))
                ((equal major-mode 'arc-mode)
                 (symex-eval-arc))
                (t (error "Symex mode: Lisp flavor not recognized!"))))
      ;; enter a "normal-like" state here momentarily, to prevent entry
      ;; into symex mode from being treated as if it was in an "emacs" context
      ;; since the entry into emacs state is done here as an implementation
      ;; detail and is not user-directed
      ;; we don't enter normal state itself but rather a clone, to go
      ;; "under the radar" of any registered hooks
      (evil-normallike-state)
      ;; ideally we shouldn't do this since it would still trigger entry
      ;; hooks, but for now that's OK
      ;; the right way to handle all this would be to avoid any state
      ;; transitions
      (funcall (intern (concat "evil-" (symbol-name original-evil-state) "-state"))))))

(defun symex-evaluate (count)
  "Evaluate COUNT symexes."
  (interactive "p")
  (save-excursion
    (let ((i 0)
          (movedp t))
      (while (or (not movedp)
                 (< i count))
        (symex--evaluate)
        (symex--go-forward)
        (setq i (1+ i))))))

(defun symex-eval-recursive ()
  "Evaluate a symex recursively.

Eval starting at the leaves and proceed down to the root, similarly
to how the Lisp interpreter does it (when it is following
'applicative-order evaluation')."
  (interactive)
  (save-excursion
    (symex-execute-traversal (symex-traversal
                              (circuit symex--traversal-preorder-in-tree)))
    (symex--do-while-traversing #'symex--evaluate
                                symex--traversal-postorder-in-tree)))

(defun symex-evaluate-remaining ()
  "Evaluate the remaining symexes at this level."
  (interactive)
  (save-excursion
    (symex--do-while-traversing #'symex--evaluate
                                (symex-make-move 1 0))))

(defun symex-evaluate-definition ()
  "Evaluate entire containing symex definition."
  (interactive)
  (cond ((member major-mode symex-racket-modes)
         (symex-eval-definition-racket))
        ((member major-mode symex-elisp-modes)
         (symex-eval-definition-elisp))
        ((equal major-mode 'scheme-mode)
         (symex-eval-definition-scheme))
        ((member major-mode symex-clojure-modes)
         (symex-eval-definition-clojure))
        ((member major-mode symex-common-lisp-modes)
         (symex-eval-definition-common-lisp))
        ((equal major-mode 'arc-mode)
         (symex-eval-definition-arc))
        (t (error "Symex mode: Lisp flavor not recognized!"))))

(defun symex-evaluate-pretty ()
  "Evaluate Symex and transform output into a useful string representation."
  (interactive)
  (save-excursion
    (forward-sexp)  ; selected symexes will have the cursor on the starting paren
    (cond ((member major-mode symex-racket-modes)
           (symex-eval-pretty-racket))
          ((member major-mode symex-elisp-modes)
           (symex-eval-pretty-elisp))
          ((equal major-mode 'scheme-mode)
           (symex-eval-pretty-scheme))
          ((member major-mode symex-clojure-modes)
           (symex-eval-pretty-clojure))
          ((member major-mode symex-common-lisp-modes)
           (symex-eval-pretty-common-lisp))
          ((equal major-mode 'arc-mode)
           (symex-eval-pretty-arc))
          (t (error "Symex mode: Lisp flavor not recognized!")))))

(defun symex-eval-print ()
  "Eval symex and print result in buffer."
  (interactive)
  (save-excursion
    (forward-sexp)
    (cond ((member major-mode symex-racket-modes)
           (symex-eval-print-racket))
          ((member major-mode symex-elisp-modes)
           (symex-eval-print-elisp))
          ((equal major-mode 'scheme-mode)
           (symex-eval-print-scheme))
          ((member major-mode symex-clojure-modes)
           (symex-eval-print-clojure))
          ((member major-mode symex-common-lisp-modes)
           (symex-eval-print-common-lisp))
          ((equal major-mode 'arc-mode)
           (symex-eval-print-arc))
          (t (error "Symex mode: Lisp flavor not recognized!")))))

(defun symex-evaluate-thunk ()
  "Evaluate symex as a thunk.

This treats the symex as a thunk -- i.e. a function that takes no
arguments -- by (transparently) wrapping it in parens and then
executing it."
  (interactive)
  (save-excursion
    (forward-sexp)  ; selected symexes will have the cursor on the starting paren
    (cond ((member major-mode symex-racket-modes)
           (symex-eval-thunk-racket))
          ((member major-mode symex-elisp-modes)
           (symex-eval-thunk-elisp))
          ((equal major-mode 'scheme-mode)
           (symex-eval-thunk-scheme))
          ((member major-mode symex-clojure-modes)
           (symex-eval-thunk-clojure))
          ((member major-mode symex-common-lisp-modes)
           (symex-eval-thunk-common-lisp))
          ((equal major-mode 'arc-mode)
           (symex-eval-thunk-arc))
          (t (error "Symex mode: Lisp flavor not recognized!")))))

(defun symex-describe ()
  "Lookup doc on symex."
  (interactive)
  (save-excursion
    (forward-sexp)  ; selected symexes will have the cursor on the starting paren
    (cond ((member major-mode symex-racket-modes)
           (symex-describe-symbol-racket))
          ((member major-mode symex-elisp-modes)
           (symex-describe-symbol-elisp))
          ((equal major-mode 'scheme-mode)
           (symex-describe-symbol-scheme))
          ((member major-mode symex-clojure-modes)
           (symex-describe-symbol-clojure))
          ((member major-mode symex-common-lisp-modes)
           (symex-describe-symbol-common-lisp))
          ((equal major-mode 'arc-mode)
           (symex-describe-symbol-arc))
          (t (error "Symex mode: Lisp flavor not recognized!")))))

(defun symex-repl ()
  "Go to REPL."
  (interactive)
  (cond ((member major-mode symex-racket-modes)
         (symex-repl-racket))
        ((member major-mode symex-elisp-modes)
         (symex-repl-elisp))
        ((equal major-mode 'scheme-mode)
         (symex-repl-scheme))
        ((member major-mode symex-clojure-modes)
         (symex-repl-clojure))
        ((member major-mode symex-common-lisp-modes)
         (symex-repl-common-lisp))
        ((equal major-mode 'arc-mode)
         (symex-repl-arc))
        (t (error "Symex mode: Lisp flavor not recognized!"))))

(defun symex-run ()
  "Send to REPL."
  (interactive)
  (cond ((member major-mode symex-racket-modes)
         (symex-run-racket))
        ((member major-mode symex-elisp-modes)
         (symex-run-elisp))
        ((equal major-mode 'scheme-mode)
         (symex-run-scheme))
        ((member major-mode symex-clojure-modes)
         (symex-run-clojure))
        ((member major-mode symex-common-lisp-modes)
         (symex-run-common-lisp))
        (t (error "Symex mode: Lisp flavor not recognized!"))))

(cl-defun symex--new-scratch-buffer (buffer-name)
  "Create a new empty buffer.

The buffer will be named BUFFER-NAME and will be created in the
currently active (at the time of command execution) major mode.
As a \"scratch\" buffer, its contents will be treated as
disposable, and it will not prompt to save if it is closed or
if Emacs is exited.

Modified from:
URL `https://ergoemacs.org/emacs/emacs_new_empty_buffer.html'
Version 2017-11-01"
  (interactive)
  (let (($buf (generate-new-buffer buffer-name))
        (major-mode-to-use major-mode))
    (with-current-buffer $buf
      (funcall major-mode-to-use)
      (setq buffer-offer-save nil))
    $buf))

(defun symex-switch-to-scratch-buffer ()
  "Switch to scratch buffer."
  (interactive)
  (let* ((buffer-name (cond ((member major-mode symex-racket-modes)
                             "*scratch - Racket*")
                            ((member major-mode symex-elisp-modes)
                             "*scratch*")
                            ((equal major-mode 'scheme-mode)
                             "*scratch - Scheme*")
                            ((member major-mode symex-clojure-modes)
                             "*scratch - Clojure*")
                            ((member major-mode symex-common-lisp-modes)
                             "*scratch - Common Lisp*")
                            (t (error "Symex mode: Lisp flavor not recognized!"))))
         (buf (get-buffer buffer-name)))
    (let ((buf (or buf (symex--new-scratch-buffer buffer-name))))
      (switch-to-buffer buf))))

(defun symex-switch-to-messages-buffer ()
  "Switch to messages buffer while retaining focus in original window."
  (interactive)
  (switch-to-buffer-other-window "*Messages*")
  (goto-char (point-max))
  (recenter)
  (evil-window-mru))

(defun symex-user-select-nearest ()
  "Select symex nearest to point.

This user-level interface does the most intuitive thing from the perspective
of the user, and isn't necessarily deterministic. It may select the next
expression, the previous one, or the containing one, depending on context.
For the deterministic version used at the primitive level, see
`symex-select-nearest`."
  (interactive)
  (symex-select-nearest)
  (when (and (symex-right-p)
             (looking-back symex--re-left
                           (line-beginning-position)))
    (symex-go-down 1)))

(defun symex-select-nearest-in-visual-line ()
  "Select symex nearest to point on the current visual line."
  (interactive)
  (unless (symex--current-visual-line-empty-p)
    (let ((original-pos (point))
          (bounds (symex--current-visual-line-bounds)))
      (symex-select-nearest)
      (unless (range-member-p (point) bounds)
        (goto-char original-pos)))))

(defun symex-remaining-length ()
  "Compute the remaining length of the current symex."
  (1+  ; length, so not zero-based like index
   (symex-save-excursion
     (symex-execute-traversal symex--traversal-goto-last
                              symex--computation-traversal-length))))

(defun symex-index ()
  "Get relative (from start of containing symex) index of current symex."
  (symex-save-excursion
    (symex-execute-traversal symex--traversal-goto-first
                             symex--computation-traversal-length)))

(defun symex-height ()
  "Get height (above root) of current symex."
  (symex-save-excursion
    (symex-execute-traversal symex--traversal-goto-lowest
                             symex--computation-traversal-length)))

(defun symex-next-visual-line (&optional count)
  "Coordinate navigation to move down.

This moves down COUNT lines in terms of buffer coordinates, rather than
structurally in terms of the tree."
  (interactive "p")
  (evil-next-visual-line count)
  (symex-select-nearest-in-visual-line))

(defun symex-previous-visual-line (&optional count)
  "Coordinate navigation to move up.

This moves up COUNT lines in terms of buffer coordinates, rather than
structurally in terms of the tree."
  (interactive "p")
  (evil-previous-visual-line count)
  (symex-select-nearest-in-visual-line))

(defun symex-soar-backward (count)
  "Leap backwards, crossing to a neighboring tree.

At the moment, if a neighboring branch in the current tree is
available in that direction, we leap to it.  In a future version of
symex, this may be changed to always go to a neighboring tree,
ignoring local branches.

Leaps COUNT times, defaulting to once."
  (interactive "p")
  (dotimes (_ count)
    (symex--leap-backward t)))

(defun symex-soar-forward (count)
  "Leap forward, crossing to a neighboring tree.

At the moment, if a neighboring branch in the current tree is
available in that direction, we leap to it.  In a future version of
symex, this may be changed to always go to a neighboring tree,
ignoring local branches.

Leaps COUNT times, defaulting to once."
  (interactive "p")
  (dotimes (_ count)
    (symex--leap-forward t)))

(defun symex-leap-backward (count)
  "Leap backward to a neighboring branch, preserving height and position.

Leaps COUNT times, defaulting to once."
  (interactive "p")
  (dotimes (_ count)
    (symex--leap-backward)))

(defun symex-leap-forward (count)
  "Leap forward to a neighboring branch, preserving height and position.

Leaps COUNT times, defaulting to once."
  (interactive "p")
  (dotimes (_ count)
    (symex--leap-forward)))

(defun symex--tree-index ()
  "Index of current tree."
  (symex-save-excursion
   (symex-goto-lowest)
   (symex-index)))

(defun symex--leap-forward (&optional soar)
  "Leap forward to a neighboring branch, preserving height and position.

If SOAR is true, leap between trees too, otherwise, stay in the
current tree.

See the documentation on `symex-leap-backward` for details regarding
the implementation -- the only difference is that this uses a preorder
traversal instead of a postorder traversal."
  (let ((traverse (if soar
                      symex--traversal-preorder
                    symex--traversal-preorder-in-tree)))
    (symex-execute-traversal
     (symex-traversal
       (maneuver (loop traverse
                       (lambda (acc)
                         (and (= (symex--move-x acc) 0)
                              (= (symex--move-y acc) 0))))))
     symex--computation-node-distance)))

(defun symex--leap-backward (&optional soar)
  "Leap backward to a neighboring branch, preserving height and position.

If SOAR is true, leap between trees too, otherwise, stay in the
current tree.

This is implemented as a postorder traversal from the starting
position, keeping track of changes to the height (nesting level from
root) and index (position along branch) while traversing, and stopping
when both the height and index delta returns to zero, based on a
computation that keeps track of this delta while traversing.

Since we only track height and index _deltas_ and don't actually
measure them anywhere, we do this traversal in O(n)."
  (let ((traverse (if soar
                      symex--traversal-postorder
                    symex--traversal-postorder-in-tree)))
    (symex-execute-traversal
     (symex-traversal
       (maneuver (loop traverse
                       (lambda (acc)
                         (and (= (symex--move-x acc) 0)
                              (= (symex--move-y acc) 0))))))
     symex--computation-node-distance)))

(defun symex-select-nearest-advice (&rest _)
  "Advice to select the nearest symex."
  (when (and (fboundp 'evil-symex-state-p)
             (evil-symex-state-p))
    (symex-user-select-nearest)))

(defun symex--selection-side-effects ()
  "Things to do as part of symex selection, e.g. after navigations."
  (interactive)
  (when symex-highlight-p
    (symex--update-overlay)))

(defun symex-selection-advice (orig-fn &rest args)
  "Attach symex selection side effects to a given function.

ORIG-FN could be any function that results in a symex being selected.
ARGS are the arguments that were passed to ORIG-FN (as any advice function
is expected to handle in Emacs)."
  (interactive)
  (let ((result (apply orig-fn args)))
    (symex--selection-side-effects)
    result))

(defun symex-selection-motion-advice (orig-fn count &rest args)
  "Attach symex selection side effects to a given function.

This is a version of `symex-selection-advice` that preserves a numeric
argument supplied by the user, and can be used when the underlying
function expects to receive one.

ORIG-FN could be any function that results in a symex being selected.
COUNT is the numeric argument provided via interactive invocation.
ARGS are the arguments that were passed to ORIG-FN (as any advice function
is expected to handle in Emacs)."
  (interactive "p")
  (let ((result (apply orig-fn count args)))
    (symex--selection-side-effects)
    result))

(defun symex--add-selection-advice ()
  "Add selection advice."
  (advice-add #'symex-go-forward :around #'symex-selection-motion-advice)
  (advice-add #'symex-go-backward :around #'symex-selection-motion-advice)
  (advice-add #'symex-go-up :around #'symex-selection-motion-advice)
  (advice-add #'symex-go-down :around #'symex-selection-motion-advice)
  (advice-add #'symex-traverse-forward :around #'symex-selection-motion-advice)
  (advice-add #'symex-traverse-backward :around #'symex-selection-motion-advice)
  (advice-add #'symex-traverse-forward-skip :around #'symex-selection-motion-advice)
  (advice-add #'symex-traverse-backward-skip :around #'symex-selection-motion-advice)
  (advice-add #'symex-leap-forward :around #'symex-selection-motion-advice)
  (advice-add #'symex-leap-backward :around #'symex-selection-motion-advice)
  (advice-add #'symex-soar-forward :around #'symex-selection-motion-advice)
  (advice-add #'symex-soar-backward :around #'symex-selection-motion-advice)
  (advice-add #'symex-goto-first :around #'symex-selection-advice)
  (advice-add #'symex-goto-last :around #'symex-selection-advice)
  (advice-add #'symex-goto-lowest :around #'symex-selection-advice)
  (advice-add #'symex-goto-highest :around #'symex-selection-advice)
  (advice-add #'symex-user-select-nearest :around #'symex-selection-advice))

(defun symex--remove-selection-advice ()
  "Remove selection advice."
  (advice-remove #'symex-go-forward #'symex-selection-motion-advice)
  (advice-remove #'symex-go-backward #'symex-selection-motion-advice)
  (advice-remove #'symex-go-up #'symex-selection-motion-advice)
  (advice-remove #'symex-go-down #'symex-selection-motion-advice)
  (advice-remove #'symex-traverse-forward #'symex-selection-motion-advice)
  (advice-remove #'symex-traverse-backward #'symex-selection-motion-advice)
  (advice-remove #'symex-traverse-forward-skip #'symex-selection-motion-advice)
  (advice-remove #'symex-traverse-backward-skip #'symex-selection-motion-advice)
  (advice-remove #'symex-leap-forward #'symex-selection-motion-advice)
  (advice-remove #'symex-leap-backward #'symex-selection-motion-advice)
  (advice-remove #'symex-soar-forward #'symex-selection-motion-advice)
  (advice-remove #'symex-soar-backward #'symex-selection-motion-advice)
  (advice-remove #'symex-goto-first #'symex-selection-advice)
  (advice-remove #'symex-goto-last #'symex-selection-advice)
  (advice-remove #'symex-goto-lowest #'symex-selection-advice)
  (advice-remove #'symex-goto-highest #'symex-selection-advice)
  (advice-remove #'symex-user-select-nearest #'symex-selection-advice))

(defun symex--remember-branch-position (orig-fn &rest args)
  "Remember branch position when descending the tree.

This pushes the current position onto a stack, which is popped
while ascending.

ORIG-FN applied to ARGS is the invocation being advised."
  (let ((position (symex-index)))
    (let ((result (apply orig-fn args)))
      (when result
        (push position symex--branch-memory))
      result)))

(defun symex--return-to-branch-position (orig-fn &rest args)
  "Return to recalled position on the branch.

ORIG-FN applied to ARGS is the invocation being advised."
  (let ((result (apply orig-fn args)))
    (when result
      (let ((position (pop symex--branch-memory)))
        (when position
          (symex--execute-tree-move (symex-make-move position 0)))))
    result))

(defun symex--clear-branch-memory ()
  "Clear the branch memory stack.

Technically, branch memory is tree-specific, and stored branch
positions are no longer relevant on a different tree than the one on
which they were recorded.  To be conservative and err on the side of
determinism here, we clear branch memory upon entering symex mode,
since may enter at arbitrary points in the code, i.e. on arbitrary
trees.

TODO: Yet, hypothetically if there were two identical trees next to
one another, then the positions from one would naturally carry over to
the other and in some sense this would be the most intuitive.  Thus,
an alternative could be to retain branch memory across trees so that
we attempt to climb each tree as if it were the last tree
climbed, which may in practice end up being more intuitive than
assuming no knowledge of the tree at all.

This may be worth exploring as a defcustom."
  (setq symex--branch-memory nil))

(defun symex--forget-branch-positions (orig-fn &rest args)
  "Forget any stored branch positions when moving to a different tree.

ORIG-FN applied to ARGS is the invocation being advised."
  (let ((result (apply orig-fn args)))
    (when result
      (setq symex--branch-memory nil))
    result))

(defun symex-exit-mode ()
  "Take necessary action upon symex mode exit."
  (unless (member evil-next-state '(emacslike normallike))
    ;; these are "internal" state transitions, used in e.g. symex-evaluate
    (deactivate-mark)
    (when symex-refocus-p
      (symex--restore-scroll-margin))
    (symex--primitive-exit)))

(provide 'symex-misc)
;;; symex-misc.el ends here
