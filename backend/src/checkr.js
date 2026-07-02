import crypto from "crypto";

const CHECKR_BASE_URL = "https://api.checkr.com/v1";

function asString(value) {
  return String(value || "").trim();
}

function splitName(fullName) {
  const parts = asString(fullName).split(/\s+/).filter(Boolean);
  const firstName = parts[0] || "Trainer";
  const lastName = parts.slice(1).join(" ") || "Applicant";
  return { firstName, lastName };
}

function hasApiKey() {
  return Boolean(asString(process.env.CHECKR_API_KEY));
}

function checkrAuthHeader() {
  const apiKey = asString(process.env.CHECKR_API_KEY);
  const encoded = Buffer.from(`${apiKey}:`).toString("base64");
  return `Basic ${encoded}`;
}

async function checkrRequest(path, options = {}) {
  if (!hasApiKey()) {
    throw new Error("CHECKR_API_KEY is not configured");
  }

  const headers = {
    Authorization: checkrAuthHeader(),
    "Content-Type": "application/json",
    ...(options.headers || {}),
  };

  const res = await fetch(`${CHECKR_BASE_URL}${path}`, {
    method: options.method || "GET",
    headers,
    body: options.body ? JSON.stringify(options.body) : undefined,
  });

  const text = await res.text();
  let parsed = null;
  try {
    parsed = text ? JSON.parse(text) : null;
  } catch {
    parsed = null;
  }

  if (!res.ok) {
    const details = parsed || text || "Unknown Checkr error";
    throw new Error(`Checkr ${res.status}: ${JSON.stringify(details)}`);
  }

  return parsed;
}

export function isCheckrEnabled() {
  return hasApiKey();
}

export async function createCheckrCandidate(input) {
  const { firstName, lastName } = splitName(input?.name);
  return checkrRequest("/candidates", {
    method: "POST",
    body: {
      first_name: firstName,
      last_name: lastName,
      email: asString(input?.email).toLowerCase(),
      phone: asString(input?.phone) || undefined,
    },
  });
}

export async function createCheckrInvitation(input) {
  const pkg = asString(process.env.CHECKR_PACKAGE) || "driver_pro";
  return checkrRequest("/invitations", {
    method: "POST",
    body: {
      candidate_id: asString(input?.candidateId),
      package: pkg,
    },
  });
}

export async function getCheckrReport(reportId) {
  const id = asString(reportId);
  if (!id) return null;
  return checkrRequest(`/reports/${encodeURIComponent(id)}`);
}

function extractHexSignature(signatureHeader = "") {
  const raw = asString(signatureHeader);
  if (!raw) return "";
  const parts = raw.split(",").map((v) => v.trim());
  for (const part of parts) {
    if (part.startsWith("sha256=")) return part.slice("sha256=".length);
  }
  return parts[0] || "";
}

export function verifyCheckrWebhookSignature(rawBody, signatureHeader) {
  const secret = asString(process.env.CHECKR_WEBHOOK_SECRET);
  if (!secret) return true;

  const received = extractHexSignature(signatureHeader);
  if (!received) return false;

  const expected = crypto
    .createHmac("sha256", secret)
    .update(rawBody)
    .digest("hex");

  try {
    return crypto.timingSafeEqual(Buffer.from(expected, "hex"), Buffer.from(received, "hex"));
  } catch {
    return false;
  }
}

export function normalizeCheckrDecision(eventType, report = {}) {
  const type = asString(eventType).toLowerCase();
  const status = asString(report?.status).toLowerCase();
  const result = asString(report?.result).toLowerCase();
  const adjudication = asString(report?.adjudication).toLowerCase();

  if (
    result === "clear" ||
    result === "passed" ||
    adjudication === "engage" ||
    adjudication === "eligible"
  ) {
    return { cleared: true, checkrStatus: status || result || adjudication || type };
  }

  if (
    result === "consider" ||
    adjudication === "review" ||
    type.includes("pre_adverse") ||
    type.includes("adverse") ||
    type.includes("suspended")
  ) {
    return { cleared: false, checkrStatus: status || result || adjudication || type };
  }

  if (status === "complete") {
    return { cleared: false, checkrStatus: status };
  }

  return { cleared: null, checkrStatus: status || result || adjudication || type || "pending" };
}

export async function maybeStartCheckrForTrainer(trainer) {
  if (!isCheckrEnabled()) {
    return { enabled: false, skipped: true, reason: "missing_checkr_api_key" };
  }

  if (!trainer?.backgroundCheckConsent) {
    return { enabled: true, skipped: true, reason: "no_background_check_consent" };
  }

  const email = asString(trainer?.email).toLowerCase();
  const name = asString(trainer?.name);
  if (!email || !name) {
    return { enabled: true, skipped: true, reason: "missing_name_or_email" };
  }

  let candidateId = asString(trainer?.checkrCandidateId);
  if (!candidateId) {
    const candidate = await createCheckrCandidate({
      name,
      email,
      phone: trainer?.phone,
    });
    candidateId = asString(candidate?.id);
  }

  let invitationId = asString(trainer?.checkrInvitationId);
  if (!invitationId && candidateId) {
    const invitation = await createCheckrInvitation({ candidateId });
    invitationId = asString(invitation?.id);
  }

  return {
    enabled: true,
    skipped: false,
    candidateId,
    invitationId,
    checkrStatus: "invitation_created",
  };
}

export function candidateIdFromCheckrEvent(event) {
  const dataObject = event?.data?.object || {};
  return asString(dataObject?.candidate_id || dataObject?.candidate?.id);
}

export function reportIdFromCheckrEvent(event) {
  const dataObject = event?.data?.object || {};
  const eventType = asString(event?.type).toLowerCase();

  if (asString(dataObject?.report_id)) return asString(dataObject.report_id);
  if (eventType.startsWith("report.") && asString(dataObject?.id)) return asString(dataObject.id);
  return "";
}
