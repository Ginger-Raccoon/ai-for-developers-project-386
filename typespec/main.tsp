import "@typespec/http";
import "@typespec/openapi3";

using TypeSpec.Http;

/** Call Booking API — simplified scheduling service */
@service(#{
  title: "Call Booking API",
})
@server("http://localhost:8080", "Local development server")
namespace CallBooking;

// ─── Models ───────────────────────────────────────────────────────────────────

/** A type of event that guests can book */
model EventType {
  /** Human-readable slug set by the owner, e.g. "30min" */
  id: string;

  title: string;
  description: string;

  /** Duration in minutes */
  duration: int32;
}

model CreateEventTypeRequest {
  /** Human-readable slug, e.g. "30min" */
  id: string;

  title: string;
  description: string;

  /** Duration in minutes */
  duration: int32;
}

/** An available time slot for a given event type */
model Slot {
  start: utcDateTime;
  end: utcDateTime;
}

/** A confirmed booking */
model Booking {
  id: string;
  eventTypeId: string;
  eventTypeTitle: string;
  guestName: string;
  guestEmail: string;
  start: utcDateTime;
  end: utcDateTime;
  createdAt: utcDateTime;
}

model CreateBookingRequest {
  eventTypeId: string;
  guestName: string;
  guestEmail: string;

  /** Must match the start of an available slot */
  start: utcDateTime;
}

model ApiError {
  message: string;
}

model UnprocessableEntityResponse {
  @statusCode statusCode: 422;
  @body body: ApiError;
}

// ─── Routes ───────────────────────────────────────────────────────────────────

/** Event type management */
@route("/api/v1/event-types")
interface EventTypes {
  /** List all event types */
  @get list(): OkResponse & Body<EventType[]>;

  /** Get a single event type by ID */
  @get read(@path id: string):
    | (OkResponse & Body<EventType>)
    | (NotFoundResponse & Body<ApiError>);

  /**
   * Create a new event type (admin).
   *
   * - 400 Bad Request — validation failed (empty title, duration ≤ 0, etc.).
   * - 409 Conflict — an event type with this `id` already exists.
   */
  @post create(@body body: CreateEventTypeRequest):
    | (CreatedResponse & Body<EventType>)
    | (BadRequestResponse & Body<ApiError>)
    | (ConflictResponse & Body<ApiError>);
}

/** Available slot discovery */
@route("/api/v1/event-types/{eventTypeId}/slots")
interface Slots {
  /**
   * Return available time slots for an event type.
   *
   * Without `date`, returns all free slots in the next 14 days starting from today.
   * With `date`, returns only slots on that specific day.
   *
   * A slot is free if no booking's time window overlaps with it.
   * An empty array means no slots are available for the requested period.
   */
  @get list(
    @path eventTypeId: string,

    /** Narrow results to a single day (ISO 8601, e.g. "2024-06-20") */
    @query date?: plainDate,
  ): (OkResponse & Body<Slot[]>) | (NotFoundResponse & Body<ApiError>);
}

/** Booking management */
@route("/api/v1/bookings")
interface Bookings {
  /**
   * List bookings sorted by start time ascending.
   *
   * Returns only bookings whose `start` is in the future (upcoming meetings).
   */
  @get list(): OkResponse & Body<Booking[]>;

  /**
   * Create a new booking (guest).
   *
   * - 400 Bad Request — validation failed (empty name, invalid email, etc.).
   * - 404 Not Found — `eventTypeId` does not exist.
   * - 409 Conflict — another booking already occupies this time slot.
   * - 422 Unprocessable Entity — the slot is outside the 14-day window
   *   or does not align with a valid slot start for this event type.
   */
  @post create(@body body: CreateBookingRequest):
    | (CreatedResponse & Body<Booking>)
    | (BadRequestResponse & Body<ApiError>)
    | (NotFoundResponse & Body<ApiError>)
    | (ConflictResponse & Body<ApiError>)
    | UnprocessableEntityResponse;
}
