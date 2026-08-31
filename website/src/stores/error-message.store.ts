import { makeAutoObservable } from 'mobx';

export type ErrorMessageSeverity = 'error' | 'warning' | 'info';

export interface ErrorMessageEntry {
  id: number;
  scope: string;
  message: string;
  severity: ErrorMessageSeverity;
  occurredAt: string;
}

class ErrorMessageStore {
  messages: ErrorMessageEntry[] = [];
  private nextId = 1;

  constructor() {
    makeAutoObservable(this);
  }

  add(scope: string, message: string, severity: ErrorMessageSeverity = 'error') {
    const normalized = message.trim();
    if (!normalized) return;

    const previous = this.messages[0];
    if (previous && previous.scope === scope && previous.message === normalized &&
        Date.now() - Date.parse(previous.occurredAt) < 5000) {
      return;
    }

    this.messages = [
      {
        id: this.nextId++,
        scope,
        message: normalized,
        severity,
        occurredAt: new Date().toISOString(),
      },
      ...this.messages,
    ].slice(0, 30);
  }

  clear() {
    this.messages = [];
  }
}

export const errorMessageStore = new ErrorMessageStore();
