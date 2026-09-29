import test from 'node:test';
import assert from 'node:assert/strict';
import { assertIsolatedStaging, blockedDevProjectRef } from './staging-guard.mjs';

function fictional(overrides = {}) {
  return {
    QA_SYNTHETIC_ONLY_ACK: 'ISOLATED_FAKE_USERS_ONLY',
    QA_SUPABASE_URL: 'https://aaaaaaaaaaaaaaaaaaaa.supabase.co',
    QA_STAGING_SITE_URL: 'https://folego-qa-synthetic.vercel.app/',
    QA_EXPECTED_STAGING_PROJECT_REF: 'aaaaaaaaaaaaaaaaaaaa',
    QA_SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_fake_synthetic_not_a_real_key_0000',
    QA_FAKE_A_EMAIL: 'a+folegoqa@test.invalid',
    QA_FAKE_A_PASSWORD: 'SYNTHETIC_A_ONLY_12345',
    QA_FAKE_B_EMAIL: 'b+folegoqa@test.invalid',
    QA_FAKE_B_PASSWORD: 'SYNTHETIC_B_ONLY_98765',
    QA_FAKE_A_PUSH_ENDPOINT: 'https://push.synthetic.invalid/fixture-A',
    ...overrides,
  };
}

test('only an explicit, independent, fake-user HTTPS staging target passes', () => {
  const approved = assertIsolatedStaging(fictional());
  assert.equal(approved.projectRef, 'aaaaaaaaaaaaaaaaaaaa');
  assert.equal(approved.stagingSiteUrl, 'https://folego-qa-synthetic.vercel.app/');
  assert.ok(Object.isFrozen(approved));
});

for (const [name, change] of [
  ['connected real-user Supabase Dev', {
    QA_SUPABASE_URL: 'https://' + blockedDevProjectRef + '.supabase.co',
    QA_EXPECTED_STAGING_PROJECT_REF: blockedDevProjectRef,
  }],
  ['ordinary real customer GitHub Pages site', {
    QA_STAGING_SITE_URL: 'https://caueccipriano.github.io/folego-app/',
  }],
  ['unapproved arbitrary HTTPS site', {
    QA_STAGING_SITE_URL: 'https://folego.com.br/',
  }],
  ['preview site named after connected project', {
    QA_STAGING_SITE_URL: 'https://folego-qa-' + blockedDevProjectRef + '.vercel.app/',
  }],
  ['insecure preview', {
    QA_STAGING_SITE_URL: 'http://folego-qa-synthetic.vercel.app/',
  }],
  ['insecure API', {
    QA_SUPABASE_URL: 'http://aaaaaaaaaaaaaaaaaaaa.supabase.co',
  }],
  ['a copied production publishable key or malformed anon key', {
    QA_SUPABASE_PUBLISHABLE_KEY: 'fake-public-anon',
  }],
  ['missing explicit fictitious data acknowledgement', {
    QA_SYNTHETIC_ONLY_ACK: '',
  }],
  ['wrong project ref prevents accidental wrong-environment credentials', {
    QA_EXPECTED_STAGING_PROJECT_REF: 'bbbbbbbbbbbbbbbbbbbb',
  }],
  ['one identity twice', {
    QA_FAKE_B_EMAIL: 'a+folegoqa@test.invalid',
  }],
  ['shared password for independent users', {
    QA_FAKE_B_PASSWORD: 'SYNTHETIC_A_ONLY_12345',
  }],
  ['unmarked personal mailboxes', {
    QA_FAKE_A_EMAIL: 'personal@example.com',
  }],
  ['actual person device endpoint rather than fake fixture', {
    QA_FAKE_A_PUSH_ENDPOINT: 'https://push.realprovider.example/private',
  }],
]) {
  test('fail closed on ' + name, () => {
    assert.throws(() => assertIsolatedStaging(fictional(change)), /STAGING_/);
  });
}

test('never include sensitive credentials in a failed guard message', () => {
  const env = fictional({
    QA_STAGING_SITE_URL: 'https://caueccipriano.github.io/folego-app/',
  });
  try {
    assertIsolatedStaging(env);
    assert.fail('guard should block a real customer site');
  } catch (error) {
    const message = String(error);
    assert.equal(message.includes(env.QA_FAKE_A_PASSWORD), false);
    assert.equal(message.includes(env.QA_FAKE_A_EMAIL), false);
  }
});
