import type { Request } from "express";
import { applicationDefault, cert, getApp, getApps, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import type { Env } from "./env.js";
import { AppError } from "./errors.js";

export const PARENT_AUTH_HEADER = "x-storytime-parent-auth";

export type ParentIdentity = {
  uid: string;
  provider: "firebase";
};

export interface ParentIdentityVerifier {
  verifyParentToken(token: string, env: Env): Promise<ParentIdentity>;
}

export async function resolveOptionalParentIdentity(
  req: Request,
  env: Env,
  verifier: ParentIdentityVerifier = new FirebaseParentIdentityVerifier()
): Promise<ParentIdentity | null> {
  const token = req.header(PARENT_AUTH_HEADER)?.trim();
  if (!token) {
    return null;
  }

  return verifier.verifyParentToken(token, env);
}

export class FirebaseParentIdentityVerifier implements ParentIdentityVerifier {
  async verifyParentToken(token: string, env: Env): Promise<ParentIdentity> {
    try {
      const decoded = await getAuth(resolveFirebaseApp(env)).verifyIdToken(token);
      return {
        uid: decoded.uid,
        provider: "firebase"
      };
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }

      throw new AppError("Invalid parent account token", 401, "invalid_parent_auth");
    }
  }
}

function resolveFirebaseApp(env: Env) {
  const appName = "storytime-parent-auth";
  if (getApps().some((app) => app.name === appName)) {
    return getApp(appName);
  }

  if (env.FIREBASE_PROJECT_ID && env.FIREBASE_CLIENT_EMAIL && env.FIREBASE_PRIVATE_KEY) {
    return initializeApp(
      {
        credential: cert({
          projectId: env.FIREBASE_PROJECT_ID,
          clientEmail: env.FIREBASE_CLIENT_EMAIL,
          privateKey: env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n")
        }),
        projectId: env.FIREBASE_PROJECT_ID
      },
      appName
    );
  }

  if (env.FIREBASE_PROJECT_ID) {
    return initializeApp(
      {
        credential: applicationDefault(),
        projectId: env.FIREBASE_PROJECT_ID
      },
      appName
    );
  }

  throw new AppError(
    "Parent auth verification is not configured on this backend.",
    503,
    "parent_auth_unavailable"
  );
}
