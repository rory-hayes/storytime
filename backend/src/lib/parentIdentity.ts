import type { Request } from "express";
import { applicationDefault, cert, getApp, getApps, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { createRemoteJWKSet, jwtVerify } from "jose";
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

type ParentIdentityVerifierDeps = {
  verifyWithFirebaseAdmin: (token: string, env: Env) => Promise<ParentIdentity>;
  verifyWithProjectID: (token: string, projectID: string) => Promise<ParentIdentity>;
};

const firebaseJWKS = createRemoteJWKSet(
  new URL("https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com")
);

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
  private readonly deps: ParentIdentityVerifierDeps;

  constructor(deps?: Partial<ParentIdentityVerifierDeps>) {
    this.deps = {
      verifyWithFirebaseAdmin: deps?.verifyWithFirebaseAdmin ?? verifyParentTokenWithFirebaseAdmin,
      verifyWithProjectID: deps?.verifyWithProjectID ?? verifyParentTokenWithProjectID
    };
  }

  async verifyParentToken(token: string, env: Env): Promise<ParentIdentity> {
    if (env.FIREBASE_PROJECT_ID && env.FIREBASE_CLIENT_EMAIL && env.FIREBASE_PRIVATE_KEY) {
      return this.deps.verifyWithFirebaseAdmin(token, env);
    }

    if (env.FIREBASE_PROJECT_ID) {
      return this.deps.verifyWithProjectID(token, env.FIREBASE_PROJECT_ID);
    }

    throw new AppError(
      "Parent auth verification is not configured on this backend.",
      503,
      "parent_auth_unavailable"
    );
  }
}

async function verifyParentTokenWithFirebaseAdmin(token: string, env: Env): Promise<ParentIdentity> {
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

async function verifyParentTokenWithProjectID(token: string, projectID: string): Promise<ParentIdentity> {
  try {
    const issuer = `https://securetoken.google.com/${projectID}`;
    const { payload } = await jwtVerify(token, firebaseJWKS, {
      issuer,
      audience: projectID
    });
    const uid = typeof payload.user_id === "string" ? payload.user_id : payload.sub;
    if (typeof uid !== "string" || uid.length === 0) {
      throw new AppError("Invalid parent account token", 401, "invalid_parent_auth");
    }

    return {
      uid,
      provider: "firebase"
    };
  } catch (error) {
    if (error instanceof AppError) {
      throw error;
    }

    throw new AppError("Invalid parent account token", 401, "invalid_parent_auth");
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
