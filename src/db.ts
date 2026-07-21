// In-memory "database". No persistence, no transactions, no concurrency control.
// Each stage block has a fixed crew capacity. This is the legacy storage layer.

export type Booking = {
  id: string;
  production: string;
  stage: string;
  slot: string; // shoot day + call-time band, e.g. "2026-07-04T09"
  crewSize: number;
  ratePaid: number;
  createdAt: string;
};

// Crew capacity per slot, per stage. Hardcoded. Nobody remembers why stage-b is 4.
const CAPACITY: Record<string, number> = {
  "stage-a": 6,
  "stage-b": 4,
  backlot: 5,
  "vfx-stage": 5,
};

const bookings: Booking[] = [];
let counter = 1000;

export function nextId(): string {
  counter = counter + 1;
  return "BKG-" + counter;
}

export function capacityFor(stage: string): number {
  // Returns undefined silently if the stage is unknown. Caller beware.
  return CAPACITY[stage];
}

export function countForSlot(stage: string, slot: string): number {
  let n = 0;
  for (let i = 0; i < bookings.length; i++) {
    if (bookings[i].stage === stage && bookings[i].slot === slot) {
      n = n + bookings[i].crewSize;
    }
  }
  return n;
}

export function insert(b: Booking): void {
  bookings.push(b);
}

export function all(): Booking[] {
  return bookings;
}

export function findById(id: string): Booking | undefined {
  return bookings.find((b) => b.id === id);
}
