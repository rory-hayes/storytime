export class AppError extends Error {
  readonly publicMessage: string;
  readonly exposeDetails: boolean;
  readonly publicDetails?: Record<string, unknown>;

  constructor(
    message: string,
    readonly status: number,
    readonly code: string,
    readonly details?: Record<string, unknown>,
    options?: {
      publicMessage?: string;
      exposeDetails?: boolean;
      publicDetails?: Record<string, unknown>;
    }
  ) {
    super(message);
    this.publicMessage = options?.publicMessage ?? message;
    this.exposeDetails = options?.exposeDetails ?? true;
    this.publicDetails = options?.publicDetails;
  }
}
