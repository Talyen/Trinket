const languages = {
  en: "English",
  de: "Deutsch",
  es: "Español",
  fr: "Français",
  ja: "日本語",
  ko: "한국어",
  "pt-BR": "Português (Brasil)",
  "zh-Hant": "繁體中文",
};

function supportedLanguage(tag) {
  const lower = tag?.toLowerCase();
  const exact = Object.keys(languages).find(language => language.toLowerCase() === lower);
  if (exact) return exact;
  if (/^zh-(?:hant|tw|hk|mo)(?:-|$)/.test(lower)) return "zh-Hant";
  const base = lower?.split("-")[0];
  return Object.hasOwn(languages, base) ? base : undefined;
}

function applyCopy(copy) {
  const elements = document.querySelectorAll("[data-copy]");
  for (const element of elements) {
    const text = copy?.[element.dataset.copy];
    const link = element.matches("p") && element.querySelector("a");
    if (typeof text !== "string" || text.split("{link}").length !== (link ? 2 : 1)) {
      throw new Error("Incomplete website translation");
    }
  }

  for (const element of elements) {
    const text = copy[element.dataset.copy];
    const link = element.matches("p") && element.querySelector("a");
    if (link) {
      const [before, after] = text.split("{link}");
      element.replaceChildren(before, link, after);
    } else if (element.matches("meta")) {
      element.content = text;
    } else if (element.hasAttribute("aria-label")) {
      element.setAttribute("aria-label", text);
    } else {
      element.textContent = text;
    }
  }
}

async function localize() {
  const url = new URL(window.location.href);
  const requested = url.searchParams.get("lang");
  let language = supportedLanguage(requested ?? "")
    ?? navigator.languages.map(supportedLanguage).find(Boolean) ?? "en";

  if (language !== "en") {
    try {
      const response = await fetch("translations.json");
      if (!response.ok) throw new Error("Website translations unavailable");
      applyCopy((await response.json())[language]);
      document.documentElement.lang = language;
    } catch {
      language = "en";
    }
  }

  for (const link of document.querySelectorAll("[data-local-page]")) {
    const target = new URL(link.href);
    target.searchParams.set("lang", language);
    link.href = target.href;
  }

  const selector = document.querySelector("#language");
  for (const [tag, name] of Object.entries(languages)) {
    const option = new Option(name, tag);
    option.lang = tag;
    selector.add(option);
  }
  selector.value = language;
  selector.addEventListener("change", () => {
    url.searchParams.set("lang", selector.value);
    window.location.assign(url);
  });
  selector.parentElement.hidden = false;
}

void localize();
