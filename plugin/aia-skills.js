/**
 * aia_kaiwu skills plugin for opencode.
 *
 * Registers this repo's real `skills/` directory into `config.skills.paths`,
 * mirroring the superpowers plugin. Paths resolve from this file's own
 * location (`__dirname`), not the `directory` hook input, and point at the
 * real `skills/` (registering the `.opencode/skills` symlink made opencode's
 * scanner miss the skills).
 *
 * Layout: this file is `<root>/plugin/aia-skills.js` (loaded through the
 * `<root>/.opencode/plugins/aia-skills.js` symlink, which Node resolves back
 * to the real path), so `../skills` lands at the repo root.
 *
 * NOTE: an `experimental.chat.system.transform` hook that re-injected the full
 * AGENTS.md into the system prompt every turn was removed. It over-forced the
 * "load a skill first every turn" mandate, which the model truncated into a
 * dangling tool call (trailing `</invoke>`), producing the provider error
 * "conversation must end with a user message". Skill registration alone is the
 * safe, superpowers-equivalent behavior.
 */

import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export const AiaSkillsPlugin = async () => {
  const skillsDir = path.resolve(__dirname, "..", "skills");

  return {
    config: async (config) => {
      config.skills = config.skills || {};
      config.skills.paths = config.skills.paths || [];
      if (!config.skills.paths.includes(skillsDir)) {
        config.skills.paths.push(skillsDir);
      }
    },
  };
};
