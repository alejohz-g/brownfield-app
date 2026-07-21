// Legacy rate-card module. Plain JavaScript, no types, written years ago.
// Surge rules are tangled with date parsing. Touch with care.
// This file is intentionally the kind of thing you point a coding agent at
// and say: "explain this, add types, write tests, do not change behavior."

function baseRate(stage) {
  if (stage === "stage-a") return 159;
  if (stage === "stage-b") return 134;
  if (stage === "backlot") return 139;
  if (stage === "vfx-stage") return 129;
  return 119; // unknown stages get the floor rate, on purpose? unclear.
}

function isPeak(slot) {
  // slot looks like "2026-07-04T09". Peak = weekend OR peak-season month (Jul, Dec).
  var datePart = slot.split("T")[0];
  var parts = datePart.split("-");
  var year = parseInt(parts[0], 10);
  var month = parseInt(parts[1], 10);
  var day = parseInt(parts[2], 10);
  var d = new Date(year, month - 1, day);
  var dow = d.getDay();
  var weekend = dow === 0 || dow === 6;
  var peakMonth = month === 7 || month === 12;
  return weekend || peakMonth;
}

function rateFor(stage, slot, crewSize) {
  var base = baseRate(stage);
  var rate = base * crewSize;
  if (isPeak(slot)) {
    rate = rate * 1.25;
  }
  // Volume discount, applied AFTER surge. Order matters and nobody documented it.
  if (crewSize >= 5) {
    rate = rate * 0.92;
  }
  return Math.round(rate * 100) / 100;
}

module.exports = { rateFor: rateFor, baseRate: baseRate, isPeak: isPeak };
