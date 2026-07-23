import data from '../data/plate-metadata.json';

// country -> district/canton/province code -> official region name.
export const kPlateRegions = data as Record<string, Record<string, string>>;
