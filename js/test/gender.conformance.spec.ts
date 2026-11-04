import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { Gender } from '../src/gender/index';
import { FormatError } from '../src/common/errors';

type Vec = { input: string; isValid?: boolean; code?: string; normalized?: string };
const vectors: Vec[] = JSON.parse(
  readFileSync(fileURLToPath(new URL('../../test/vectors/gender.json', import.meta.url)), 'utf8'),
);

describe('gender conformance', () => {
  for (const v of vectors) {
    it(`gender: "${v.input}"`, () => {
      const r = Gender.validate(v.input);
      if (v.isValid !== undefined) expect(r.ok).toBe(v.isValid);
      if (v.code !== undefined) expect(r.ok ? undefined : r.issues[0].code).toBe(v.code);
      if (v.normalized !== undefined && r.ok) expect(r.normalized).toBe(v.normalized);
      expect(Gender.isValid(v.input)).toBe(r.ok);
    });
  }
});

describe('gender', () => {
  it('lists the five values in a fixed order', () => {
    expect(Gender.values).toEqual(['m', 'f', 'd', 'i', 'o']);
  });

  it('labels every value in German (default) and English', () => {
    expect(Gender.values.map((v) => Gender.label(v))).toEqual(['männlich', 'weiblich', 'divers', 'inter', 'offen']);
    expect(Gender.values.map((v) => Gender.label(v, 'en'))).toEqual(['male', 'female', 'diverse', 'inter', 'open']);
  });

  it('options pair every value with its label, in order', () => {
    expect(Gender.options()).toEqual([
      { value: 'm', label: 'männlich' },
      { value: 'f', label: 'weiblich' },
      { value: 'd', label: 'divers' },
      { value: 'i', label: 'inter' },
      { value: 'o', label: 'offen' },
    ]);
    expect(Gender.options('en')[1]).toEqual({ value: 'f', label: 'female' });
  });

  it('normalize returns the code and throws FormatError on unknown input', () => {
    expect(Gender.normalize('Weiblich')).toBe('f');
    expect(() => Gender.normalize('keine angabe')).toThrow(FormatError);
  });

  it('label accepts any valid input and throws on an unknown one', () => {
    expect(Gender.label('W')).toBe('weiblich');
    expect(() => Gender.label('x')).toThrow(FormatError);
  });
});
