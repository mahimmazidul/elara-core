// Original work: Vani by nkrider7
// https://github.com/nkrider7/vani
// Original license: MIT, as stated in the upstream README.
//
// Inspected by Md. Mazidul Islam Mahim, 2026. Vani was not ported.
// See ATTRIBUTION.md for full details.

// Vani inspection: https://github.com/nkrider7/vani, commit e5f69dc.
// Its calendar strategy is a mean and its default strategy is a weighted mean,
// with standard-deviation-based confidence/window and an irregularity note.
// That adds no distinct prediction method to this ensemble, so it is skipped.
// One upstream detail worth keeping: the WMA code reverses its weights after
// calculating them, giving *older* intervals more weight despite its comment.
// Fertility dates are the same fixed 14-day/5-day calendar arithmetic already
// requested for ELARA. No Vani source is copied or included as an engine.
