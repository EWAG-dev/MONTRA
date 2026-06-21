import { getFirestore } from "./firebase.js";

const CONVERSATIONS = "conversations";
const MESSAGES = "conversationMessages";

function conversationsCollection() {
  return getFirestore().collection(CONVERSATIONS);
}

function messagesCollection() {
  return getFirestore().collection(MESSAGES);
}

function normalizeString(value) {
  return String(value || "").trim();
}

export function conversationIdFor({ trainerId, clientUid }) {
  return `trainer_${normalizeString(trainerId)}__client_${normalizeString(clientUid)}`;
}

function serializeConversation(doc) {
  const data = doc.data();
  return {
    id: doc.id,
    trainerId: data.trainerId || "",
    trainerName: data.trainerName || "",
    clientUid: data.clientUid || "",
    clientEmail: data.clientEmail || "",
    clientName: data.clientName || "",
    lastMessage: data.lastMessage || "",
    lastMessageAt: data.lastMessageAt || null,
    lastSenderUid: data.lastSenderUid || "",
    lastSenderRole: data.lastSenderRole || "",
    createdAt: data.createdAt || null,
    updatedAt: data.updatedAt || null,
  };
}

function serializeMessage(doc) {
  const data = doc.data();
  return {
    id: doc.id,
    conversationId: data.conversationId || "",
    senderUid: data.senderUid || "",
    senderRole: data.senderRole || "",
    senderName: data.senderName || "",
    text: data.text || "",
    createdAt: data.createdAt || null,
  };
}

export async function ensureConversationThread(input) {
  const trainerId = normalizeString(input.trainerId);
  const clientUid = normalizeString(input.clientUid);
  const conversationId = conversationIdFor({ trainerId, clientUid });
  const ref = conversationsCollection().doc(conversationId);
  const existing = await ref.get();
  const now = new Date().toISOString();

  const payload = {
    trainerId,
    clientUid,
    trainerName: normalizeString(input.trainerName),
    clientEmail: normalizeString(input.clientEmail),
    clientName: normalizeString(input.clientName),
    lastMessage: existing.data()?.lastMessage || "",
    lastMessageAt: existing.data()?.lastMessageAt || null,
    lastSenderUid: existing.data()?.lastSenderUid || "",
    lastSenderRole: existing.data()?.lastSenderRole || "",
    createdAt: existing.data()?.createdAt || now,
    updatedAt: now,
  };

  await ref.set(payload, { merge: true });
  return {
    id: conversationId,
    ...payload,
  };
}

export async function getConversation(conversationId) {
  const snapshot = await conversationsCollection().doc(normalizeString(conversationId)).get();
  return snapshot.exists ? serializeConversation(snapshot) : null;
}

export async function listConversationsForClient(clientUid) {
  const snapshot = await conversationsCollection().where("clientUid", "==", normalizeString(clientUid)).get();
  return snapshot.docs.map(serializeConversation).sort((left, right) => String(right.updatedAt).localeCompare(String(left.updatedAt)));
}

export async function listConversationsForTrainer(trainerId) {
  const snapshot = await conversationsCollection().where("trainerId", "==", normalizeString(trainerId)).get();
  return snapshot.docs.map(serializeConversation).sort((left, right) => String(right.updatedAt).localeCompare(String(left.updatedAt)));
}

export async function listConversationMessages(conversationId) {
  const snapshot = await messagesCollection()
    .where("conversationId", "==", normalizeString(conversationId))
    .orderBy("createdAt", "asc")
    .get();

  return snapshot.docs.map(serializeMessage);
}

export async function sendConversationMessage(input) {
  const conversationId = normalizeString(input.conversationId);
  const text = normalizeString(input.text);

  if (!conversationId) {
    throw new Error("conversationId is required");
  }

  if (!text) {
    throw new Error("Message text is required");
  }

  const now = new Date().toISOString();
  const payload = {
    conversationId,
    senderUid: normalizeString(input.senderUid),
    senderRole: normalizeString(input.senderRole),
    senderName: normalizeString(input.senderName),
    text,
    createdAt: now,
  };

  const ref = await messagesCollection().add(payload);
  await conversationsCollection().doc(conversationId).set(
    {
      lastMessage: text,
      lastMessageAt: now,
      lastSenderUid: payload.senderUid,
      lastSenderRole: payload.senderRole,
      updatedAt: now,
    },
    { merge: true }
  );

  return {
    id: ref.id,
    ...payload,
  };
}
