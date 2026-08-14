# DPDA — Mojolicious + jQuery + Bootstrap 5

A port of the original Dancer2 (Template Toolkit) app to Mojolicious,
using Bootstrap 5 for layout/styling and jQuery for the one bit of
client-side interactivity the app needs.

## Layout

```
lib/DPDA.pm                       Mojolicious app class (routes)
lib/DPDA/Controller/Quiz.pm       All the quiz logic (was DPDA.pm)
templates/layouts/default.html.ep Bootstrap 5 page shell (was main.tt)
templates/quiz/overview.html.ep
templates/quiz/sample.html.ep
templates/quiz/question.html.ep
templates/quiz/chart.html.ep
public/css/style.css              Small overrides on top of Bootstrap
public/js/dpda.js                 Shared jQuery bits
public/dpda-questions.txt         *** PLACEHOLDER — see below ***
script/dpda                       App launcher (morbo/hypnotoad)
cpanfile
```

## Running it

```
cpanm --installdeps .
morbo script/dpda        # dev server with auto-reload, http://127.0.0.1:3000
# or, in production:
hypnotoad script/dpda
```

## What changed, and why

- **Routing/controller** — Dancer2's `get`/`post` DSL became named routes in
  `DPDA.pm` dispatching to `DPDA::Controller::Quiz`, one method per route.
- **Modern Perl** — the controller uses `Mojo::Base -signatures` (subroutine
  signatures instead of `my ($self) = @_;` boilerplate), `state` for
  caching the question list per worker instead of re-reading the file on
  every request, and `Mojo::File` (`->child`, `->slurp`, `->spurt`,
  `->make_path`) instead of raw `open`/`close`/`die`.
- **Session handling** — the old app stored quiz history as a **plain,
  unsigned cookie** (`category|answer` pairs), which a user could edit by
  hand. It's now stored in Mojolicious's built-in **signed session**
  (`$self->session(history => {...})`), so it's tamper-evident and there's
  no more manual cookie-string parsing. The hidden `history` form fields in
  `question.tt` were dead code in the original (the POST handler never read
  them) and have been dropped.
- **Templates** — Template Toolkit (`.tt`) became Mojolicious's built-in
  `.html.ep` (Embedded Perl) templates, with a proper `layout` instead of a
  hand-rolled `[% INCLUDE head.tt %]` on every page.
- **Bootstrap 5** replaces the old hand-written CSS for layout, the nav,
  tables, and forms. `public/css/style.css` now only holds the couple of
  small tweaks Bootstrap doesn't cover.
- **Progress bar** — the third-party `jquery.lineProgressbar` plugin was
  dropped in favor of Bootstrap 5's native `.progress` component (one less
  dependency to serve/maintain); jQuery is still used for the one dynamic
  behavior the page needs — enabling the submit button once an answer is
  picked.
- **Chart generation** — still `GD::Graph::bars`, unchanged in spirit; the
  PNG is written via `Mojo::File->spurt` instead of manual filehandle
  juggling.
- **Regex hardening** — the category-counting `grep` in the old `/chart`
  handler built a regex directly from category names (`/^$category?.*$/`,
  which also had a stray `?`); it's now `/^\Q$category\E\b/` (quoted,
  word-boundary-anchored).

## ⚠️ You need to supply `public/dpda-questions.txt`

The uploaded files didn't include the real question bank, so
`public/dpda-questions.txt` is a **small placeholder** (a couple of sample
questions per category) just so the app boots and you can see the flow
end-to-end. Replace it with your actual file — same `category id flag|question
text` pipe-delimited format as before — before deploying.

## Images

`sample-chart.png`, `dpda-no-disorder.png`, `dpda-inconclusive.png`, and
`dpda-disordered.png` are now included in `public/images/`, so the
overview/sample/chart page thumbnails work out of the box.

`background.png` (the gray circle) was also supplied but isn't referenced
anywhere in the original app or its CSS, so it's included in
`public/images/` for you to use but isn't wired into any template.
