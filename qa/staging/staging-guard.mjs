// Hard stop: authenticated launch QA must NEVER target Fôlego's connected
// Supabase Dev/real-user project or its public deployment.
// Both connected production-like projects contain real user data.
const REAL_DEV_REF = 'ycumrvkwqizlnehelhek';
const OTHER_CONNECTED_REF = 'jhxhbgprjqppzfrjdfvj';

function required(env, key) {
  const value = env[key]?.trim();
  if (!value) throw new Error('STAGING_CONFIG_MISSING_' + key);
  return value;
}

function url(value, key) {
  try {
    return new URL(value);
  } catch (_) {
    throw new Error('STAGING_INVALID_URL_' + key);
  }
}

export function assertIsolatedStaging(env) {
  if (env.QA_SYNTHETIC_ONLY_ACK !== 'ISOLATED_FAKE_USERS_ONLY') {
    throw new Error('STAGING_EXPLICIT_FAKE_DATA_ACK_REQUIRED');
  }

  const supabase = url(required(env, 'QA_SUPABASE_URL'), 'QA_SUPABASE_URL');
  const site = url(required(env, 'QA_STAGING_SITE_URL'), 'QA_STAGING_SITE_URL');
  if (supabase.username || supabase.password ||
      site.username || site.password ||
      supabase.search || supabase.hash ||
      site.search || site.hash ||
      supabase.pathname !== '/' ||
      supabase.port || site.port) {
    throw new Error('STAGING_UNEXPECTED_URL_COMPONENTS');
  }
  if (supabase.protocol !== 'https:' || site.protocol !== 'https:') {
    throw new Error('STAGING_HTTPS_REQUIRED');
  }
  if (!/^[a-z0-9]{20}\.supabase\.co$/.test(supabase.hostname)) {
    throw new Error('STAGING_PROJECT_HOST_UNEXPECTED');
  }
  const projectRef = supabase.hostname.split('.')[0];
  if (projectRef === REAL_DEV_REF ||
      projectRef === OTHER_CONNECTED_REF ||
      supabase.href.includes(REAL_DEV_REF) ||
      site.href.includes(REAL_DEV_REF) ||
      supabase.href.includes(OTHER_CONNECTED_REF) ||
      site.href.includes(OTHER_CONNECTED_REF)) {
    throw new Error('STAGING_REAL_USER_DEV_PROJECT_FORBIDDEN');
  }
  if (!/^[a-z0-9]{20}$/.test(projectRef)) {
    throw new Error('STAGING_PROJECT_REF_UNEXPECTED');
  }
  if (required(env, 'QA_EXPECTED_STAGING_PROJECT_REF') !== projectRef) {
    throw new Error('STAGING_PROJECT_REF_MISMATCH');
  }
  if (site.hostname === 'caueccipriano.github.io' ||
      site.hostname === 'localhost' ||
      site.hostname === '127.0.0.1' ||
      site.hostname === supabase.hostname) {
    throw new Error('STAGING_SITE_MUST_BE_INDEPENDENT_HTTPS_PREVIEW');
  }
  // Explicit preview-only host; never make authenticated UI tests against
  // an arbitrary public customer website. Add support only after review.
  if (!site.hostname.endsWith('.vercel.app') ||
      !site.hostname.startsWith('folego-qa-')) {
    throw new Error('STAGING_PREVIEW_HOST_NOT_ALLOWLISTED');
  }

  const key = required(env, 'QA_SUPABASE_PUBLISHABLE_KEY');
  if (!key.startsWith('sb_publishable_') || key.length < 35) {
    throw new Error('STAGING_INVALID_PUBLISHABLE_KEY');
  }

  const a = required(env, 'QA_FAKE_A_EMAIL').toLowerCase();
  const b = required(env, 'QA_FAKE_B_EMAIL').toLowerCase();
  const aPassword = required(env, 'QA_FAKE_A_PASSWORD');
  const bPassword = required(env, 'QA_FAKE_B_PASSWORD');

  if (a === b || aPassword === bPassword ||
      !a.includes('@') || !b.includes('@')) {
    throw new Error('STAGING_TWO_DISTINCT_TEST_IDENTITIES_REQUIRED');
  }
  // This marker is added only to explicitly fictional users in the isolated
  // staging project; never feed personal or real-customer email accounts.
  if (!a.endsWith('@test.invalid') || !b.endsWith('@test.invalid') ||
      !a.includes('+folegoqa') || !b.includes('+folegoqa')) {
    throw new Error('STAGING_FAKE_USER_EMAIL_MARKER_REQUIRED');
  }
  const endpoint = required(env, 'QA_FAKE_A_PUSH_ENDPOINT');
  if (!endpoint.startsWith('https://push.synthetic.invalid/')) {
    throw new Error('STAGING_FAKE_PUSH_ENDPOINT_REQUIRED');
  }
  // Do not log emails, tokens, credentials, endpoint URL or any user data.
  return Object.freeze({
    projectRef,
    supabaseUrl: supabase.origin,
    stagingSiteUrl: site.href,
  });
}

export const blockedDevProjectRef = REAL_DEV_REF;
