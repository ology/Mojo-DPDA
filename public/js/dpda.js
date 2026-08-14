/**
 * DPDA - shared front-end behavior.
 * Page-specific behavior (e.g. the question page's radio-button
 * handling) lives inline in that template's `scripts` content block.
 */
$(function () {
    // Enable Bootstrap tooltips/popovers globally, if any appear later.
    $('[data-bs-toggle="tooltip"]').tooltip();
});
