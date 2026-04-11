"use client";

import { useEffect, useLayoutEffect, useRef, useState } from "react";
import { toPng } from "html-to-image";

/* ----------------------------- Constants ------------------------------ */

// Design canvas — iPhone 6.9" (largest App Store size)
const W = 1320;
const H = 2868;

const IPHONE_SIZES = [
  { label: '6.9"', w: 1320, h: 2868 },
  { label: '6.5"', w: 1284, h: 2778 },
  { label: '6.3"', w: 1206, h: 2622 },
  { label: '6.1"', w: 1125, h: 2436 },
] as const;

// Mockup.png measurements (pre-measured)
const MK_W = 1022;
const MK_H = 2082;
const MK_RATIO = MK_W / MK_H;
const SC_L = (52 / MK_W) * 100;
const SC_T = (46 / MK_H) * 100;
const SC_W = (918 / MK_W) * 100;
const SC_H = (1990 / MK_H) * 100;
const SC_RX = (126 / 918) * 100;
const SC_RY = (126 / 1990) * 100;

// Width formula — phone as fraction of canvas width
function phoneW(cW: number, cH: number, clamp = 0.84) {
  return Math.min(clamp, 0.72 * (cH / cW) * MK_RATIO);
}

/* ------------------------------ Palette ------------------------------- */

const CREAM = "#F6EEE0";
const CREAM_2 = "#EADFC7";
const ESPRESSO = "#1A120B";
const ESPRESSO_2 = "#2B1E13";
const INK = "#1B1410";
const MUTED = "#7A6A58";
const ACCENT = "#4F46E5"; // indigo — studious
const GOLD = "#E6B34B";
const TERRA = "#C7502E";

/* ---------------------- Phone Placement (EDIT ME) ----------------------
   Every main slide reads its phone position from PLACEMENT[slide.id].
   Tweak the numbers here instead of hunting through slide components.

   Per-slide knobs:
   - widthPct:      phone LAYOUT size as % of canvas width (77 = 77%).
                    This is the baseline "how big is this phone" dial.
   - translateXPct: shift phone sideways by % of canvas width
                    (positive = right, negative = left, omit = centered)
   - translateYPct: push phone down by % of its OWN height
                    (14 = 14% of the phone hangs off the bottom)
   - scale:         CSS scale() multiplier applied on top of widthPct
                    (1 = no change, 0.9 = 10% smaller, 1.1 = 10% bigger).
                    Use this for fine tuning without resizing the layout.
   - rotateDeg:     rotate the phone in degrees (omit = upright)

   Example — slide 2's phone smaller, shifted right, slight scale, tilted:
     block: {
       widthPct: 72, translateXPct: 8, translateYPct: 14,
       scale: 0.95, rotateDeg: -4,
     }

   Split demos: each is a call to makeTiltedSplit(angle, half, id, headline).
   Edit the angle (30/45/60) or the width/vertical-center inside the factory
   itself if you want to adjust size or seam position.
*/

type Placement = {
  widthPct: number;
  translateXPct?: number;
  translateYPct?: number;
  scale?: number;
  rotateDeg?: number;
};

const PLACEMENT: Record<string, Placement> = {
  pain:    { widthPct: 77, translateYPct: 14 },
  block:   { widthPct: 77, translateYPct: 14 },
  choice:  { widthPct: 77, translateYPct: 14 },
  receipt: { widthPct: 77, translateYPct: 14 },
  real:    { widthPct: 77, translateYPct: 14 },
};

// Shared phone style for the main (non-split) slides — bottom-anchored,
// centered horizontally by default, with optional per-slide overrides.
function centeredBottomStyle(p: Placement): React.CSSProperties {
  const tx = p.translateXPct ?? 0;
  const ty = p.translateYPct ?? 0;
  const sc = p.scale ?? 1;
  const rot = p.rotateDeg ?? 0;
  return {
    position: "absolute",
    bottom: 0,
    width: `${p.widthPct}%`,
    left: `calc(50% + ${tx}%)`,
    transform: `translateX(-50%) translateY(${ty}%) scale(${sc}) rotate(${rot}deg)`,
  };
}

/* --------------------------- Image Preload ---------------------------- */

const IMAGE_PATHS = [
  "/mockup.png",
  "/app-icon.png",
  "/screenshots/shield.png",
  "/screenshots/math-simple.png",
  "/screenshots/math-fraction.png",
  "/screenshots/done.png",
  "/screenshots/dashboard.png",
];

const imageCache: Record<string, string> = {};

async function preloadAllImages() {
  await Promise.all(
    IMAGE_PATHS.map(async (path) => {
      const resp = await fetch(path);
      const blob = await resp.blob();
      const dataUrl = await new Promise<string>((resolve) => {
        const reader = new FileReader();
        reader.onloadend = () => resolve(reader.result as string);
        reader.readAsDataURL(blob);
      });
      imageCache[path] = dataUrl;
    }),
  );
}

function img(path: string): string {
  return imageCache[path] || path;
}

/* --------------------------- Phone Component -------------------------- */

function Phone({
  src,
  alt,
  style,
}: {
  src: string;
  alt: string;
  style?: React.CSSProperties;
}) {
  return (
    <div style={{ position: "relative", aspectRatio: `${MK_W}/${MK_H}`, ...style }}>
      <img
        src={img("/mockup.png")}
        alt=""
        style={{ display: "block", width: "100%", height: "100%" }}
        draggable={false}
      />
      <div
        style={{
          position: "absolute",
          zIndex: 10,
          overflow: "hidden",
          left: `${SC_L}%`,
          top: `${SC_T}%`,
          width: `${SC_W}%`,
          height: `${SC_H}%`,
          borderRadius: `${SC_RX}% / ${SC_RY}%`,
        }}
      >
        <img
          src={src}
          alt={alt}
          style={{
            display: "block",
            width: "100%",
            height: "100%",
            objectFit: "cover",
            objectPosition: "top",
          }}
          draggable={false}
        />
      </div>
    </div>
  );
}

/* -------------------------- Caption Component ------------------------- */

function Caption({
  cW,
  headline,
  fgColor = INK,
  align = "center",
  maxWidth = "86%",
}: {
  cW: number;
  headline: React.ReactNode;
  fgColor?: string;
  align?: "left" | "center" | "right";
  maxWidth?: string;
}) {
  return (
    <div
      style={{
        textAlign: align,
        maxWidth,
        marginLeft: align === "center" ? "auto" : 0,
        marginRight: align === "center" ? "auto" : 0,
      }}
    >
      <div
        style={{
          fontFamily: "var(--font-serif), Georgia, serif",
          fontSize: cW * 0.098,
          fontWeight: 400,
          lineHeight: 1.0,
          letterSpacing: -cW * 0.0012,
          color: fgColor,
        }}
      >
        {headline}
      </div>
    </div>
  );
}

/* -------------------------- Decorative Blobs -------------------------- */

function SoftBlob({
  color,
  size,
  top,
  left,
  opacity = 0.45,
}: {
  color: string;
  size: string;
  top: string;
  left: string;
  opacity?: number;
}) {
  return (
    <div
      style={{
        position: "absolute",
        top,
        left,
        width: size,
        height: size,
        borderRadius: "50%",
        background: color,
        filter: "blur(90px)",
        opacity,
        pointerEvents: "none",
      }}
    />
  );
}

/* ------------------------------- Slides ------------------------------- */

type SlideProps = { cW: number; cH: number };
type SlideDef = { id: string; component: (p: SlideProps) => React.JSX.Element };

// Slide 1 — Hero (math-simple). The pain in the headline, the flip in the image.
// Works completely alone — problem + unexpected math visible = intrigue.
const slide1: SlideDef = {
  id: "pain",
  component: ({ cW, cH }) => {
    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          position: "relative",
          overflow: "hidden",
          background: `linear-gradient(180deg, ${CREAM} 0%, ${CREAM_2} 100%)`,
        }}
      >
        <SoftBlob color={GOLD} size="60%" top="-15%" left="-10%" opacity={0.35} />
        <SoftBlob color={TERRA} size="55%" top="-5%" left="55%" opacity={0.22} />
        <div
          style={{
            position: "absolute",
            top: cH * 0.075,
            left: 0,
            right: 0,
          }}
        >
          <Caption
            cW={cW}
            headline={
              <>
                you just lost
                <br />
                an hour to reels.
                <br />
                <span style={{ fontStyle: "italic" }}>again.</span>
              </>
            }
          />
        </div>
        <Phone
          src={img("/screenshots/math-simple.png")}
          alt="Math problem"
          style={centeredBottomStyle(PLACEMENT.pain)}
        />
      </div>
    );
  },
};

// Slide 2 — Dark contrast (shield). The block moment, the reveal.
const slide2: SlideDef = {
  id: "block",
  component: ({ cW, cH }) => {
    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          position: "relative",
          overflow: "hidden",
          background: `linear-gradient(170deg, ${ESPRESSO} 0%, ${ESPRESSO_2} 60%, #3A2615 100%)`,
        }}
      >
        <SoftBlob color={GOLD} size="70%" top="-20%" left="-20%" opacity={0.18} />
        <SoftBlob color={TERRA} size="55%" top="35%" left="60%" opacity={0.15} />
        <div
          style={{
            position: "absolute",
            top: cH * 0.085,
            left: cW * 0.07,
            width: cW * 0.86,
          }}
        >
          <Caption
            cW={cW}
            headline={
              <>
                the button
                <br />
                is math now.
              </>
            }
            fgColor="#F6EEE0"
            align="left"
            maxWidth="100%"
          />
        </div>
        <Phone
          src={img("/screenshots/shield.png")}
          alt="Shield"
          style={centeredBottomStyle(PLACEMENT.block)}
        />
      </div>
    );
  },
};

// Slide 3 — Agency (done). Emotional win, not a number.
const slide3: SlideDef = {
  id: "choice",
  component: ({ cW, cH }) => {
    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          position: "relative",
          overflow: "hidden",
          background: `linear-gradient(180deg, ${CREAM} 0%, ${CREAM_2} 100%)`,
        }}
      >
        {/* Radial halo behind phone */}
        <div
          style={{
            position: "absolute",
            bottom: "-10%",
            left: "50%",
            transform: "translateX(-50%)",
            width: "95%",
            height: "75%",
            borderRadius: "50%",
            background: `radial-gradient(closest-side, rgba(79,70,229,0.22), rgba(79,70,229,0) 70%)`,
            pointerEvents: "none",
          }}
        />
        <SoftBlob color={GOLD} size="45%" top="-5%" left="-12%" opacity={0.3} />
        <div
          style={{
            position: "absolute",
            top: cH * 0.085,
            left: 0,
            right: 0,
          }}
        >
          <Caption
            cW={cW}
            headline={
              <>
                you scrolled
                <br />
                this because
                <br />
                you <span style={{ fontStyle: "italic" }}>chose</span> to.
              </>
            }
          />
        </div>
        <Phone
          src={img("/screenshots/done.png")}
          alt="Session complete"
          style={centeredBottomStyle(PLACEMENT.choice)}
        />
      </div>
    );
  },
};

// Slide 4 — The receipt (dashboard). Accountability without a lecture.
const slide4: SlideDef = {
  id: "receipt",
  component: ({ cW, cH }) => {
    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          position: "relative",
          overflow: "hidden",
          background: `linear-gradient(200deg, #F1E7D4 0%, ${CREAM} 100%)`,
        }}
      >
        <SoftBlob color={ACCENT} size="55%" top="-10%" left="50%" opacity={0.16} />
        <SoftBlob color={TERRA} size="40%" top="65%" left="-15%" opacity={0.18} />
        <div
          style={{
            position: "absolute",
            top: cH * 0.085,
            left: 0,
            right: 0,
          }}
        >
          <Caption
            cW={cW}
            headline={
              <>
                the receipt
                <br />
                you didn&apos;t
                <br />
                ask for.
              </>
            }
          />
        </div>
        <Phone
          src={img("/screenshots/dashboard.png")}
          alt="Dashboard"
          style={centeredBottomStyle(PLACEMENT.receipt)}
        />
      </div>
    );
  },
};

// Slide 5 — For the skeptics (math-fraction). Acknowledges doubt, confirms.
const slide5: SlideDef = {
  id: "real",
  component: ({ cW, cH }) => {
    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          position: "relative",
          overflow: "hidden",
          background: `linear-gradient(180deg, ${CREAM} 0%, #EADFC7 100%)`,
        }}
      >
        <SoftBlob color={ACCENT} size="55%" top="-15%" left="55%" opacity={0.22} />
        <SoftBlob color={GOLD} size="40%" top="70%" left="-10%" opacity={0.22} />
        <div
          style={{
            position: "absolute",
            top: cH * 0.085,
            left: 0,
            right: 0,
          }}
        >
          <Caption
            cW={cW}
            headline={
              <>
                yeah.
                <br />
                the math
                <br />
                is <span style={{ fontStyle: "italic" }}>real</span>.
              </>
            }
          />
        </div>
        <Phone
          src={img("/screenshots/math-fraction.png")}
          alt="ACT-level math problem"
          style={centeredBottomStyle(PLACEMENT.real)}
        />
      </div>
    );
  },
};

/* ------------------------- Tilted Split Demos -------------------------
   Two adjacent slides share a phone centered at the seam between them
   and rotated by the same angle. Each panel's overflow: hidden clips
   its half, so when viewed side by side in the App Store carousel the
   phone appears to cross the seam at a diagonal.

   Math: place the phone's center at (100%, 55%) for the LEFT panel and
   (0%, 55%) for the RIGHT panel, then rotate around that center.
   translate(-50%, -50%) moves the element's top-left anchor by half its
   own width/height so the center lands on the anchor. 65% width (vs
   the 84% used in the main slides) keeps the rotated bounding box from
   crashing into the top/bottom of the canvas at any angle. */

function makeTiltedSplit(
  angle: number,
  half: "left" | "right",
  id: string,
  headline: React.ReactNode,
): SlideDef {
  return {
    id,
    component: ({ cW, cH }) => {
      const fw = 65;
      return (
        <div
          style={{
            width: "100%",
            height: "100%",
            position: "relative",
            overflow: "hidden",
            background: `linear-gradient(180deg, ${CREAM} 0%, ${CREAM_2} 100%)`,
          }}
        >
          <SoftBlob
            color={GOLD}
            size="70%"
            top="-5%"
            left={half === "left" ? "35%" : "-25%"}
            opacity={0.38}
          />
          <SoftBlob
            color={TERRA}
            size="45%"
            top="60%"
            left={half === "left" ? "55%" : "-10%"}
            opacity={0.18}
          />
          <div
            style={{
              position: "absolute",
              top: cH * 0.06,
              left: cW * 0.07,
              right: cW * 0.07,
            }}
          >
            <Caption
              cW={cW}
              headline={headline}
              align={half === "left" ? "left" : "right"}
              maxWidth="100%"
            />
          </div>
          <Phone
            src={img("/screenshots/shield.png")}
            alt="Shield"
            style={{
              position: "absolute",
              width: `${fw}%`,
              left: half === "left" ? "100%" : "0%",
              top: "55%",
              transform: `translate(-50%, -50%) rotate(${angle}deg)`,
              transformOrigin: "center",
            }}
          />
        </div>
      );
    },
  };
}

const slideSplit30L = makeTiltedSplit(
  30,
  "left",
  "split-30-a",
  <>the block.</>,
);
const slideSplit30R = makeTiltedSplit(
  30,
  "right",
  "split-30-b",
  <>the fix.</>,
);
const slideSplit45L = makeTiltedSplit(
  45,
  "left",
  "split-45-a",
  <>the block.</>,
);
const slideSplit45R = makeTiltedSplit(
  45,
  "right",
  "split-45-b",
  <>the fix.</>,
);
const slideSplit60L = makeTiltedSplit(
  60,
  "left",
  "split-60-a",
  <>the block.</>,
);
const slideSplit60R = makeTiltedSplit(
  60,
  "right",
  "split-60-b",
  <>the fix.</>,
);

const SLIDES: SlideDef[] = [
  slide1,
  slide2,
  slide3,
  slide4,
  slide5,
  slideSplit30L,
  slideSplit30R,
  slideSplit45L,
  slideSplit45R,
  slideSplit60L,
  slideSplit60R,
];

/* -------------------------- Preview Component ------------------------- */

function ScreenshotPreview({
  slide,
  cW,
  cH,
  onExport,
  index,
}: {
  slide: SlideDef;
  cW: number;
  cH: number;
  onExport: (i: number) => void;
  index: number;
}) {
  const cardRef = useRef<HTMLDivElement>(null);
  const innerRef = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState(0.2);

  useLayoutEffect(() => {
    if (!cardRef.current) return;
    const ro = new ResizeObserver(() => {
      const cardW = cardRef.current!.clientWidth;
      setScale(cardW / cW);
    });
    ro.observe(cardRef.current);
    return () => ro.disconnect();
  }, [cW]);

  return (
    <div style={{ position: "relative" }}>
      <div
        ref={cardRef}
        style={{
          width: "100%",
          aspectRatio: `${cW}/${cH}`,
          borderRadius: 14,
          overflow: "hidden",
          background: "#fff",
          boxShadow: "0 4px 24px rgba(0,0,0,0.08)",
          position: "relative",
        }}
      >
        <div
          ref={innerRef}
          style={{
            width: cW,
            height: cH,
            transform: `scale(${scale})`,
            transformOrigin: "top left",
          }}
        >
          {slide.component({ cW, cH })}
        </div>
      </div>
      <div
        style={{
          marginTop: 8,
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          fontSize: 12,
          color: "#6b7280",
          fontFamily: "var(--font-sans), system-ui, sans-serif",
        }}
      >
        <span style={{ fontWeight: 600 }}>
          {String(index + 1).padStart(2, "0")} · {slide.id}
        </span>
        <button
          onClick={() => onExport(index)}
          style={{
            padding: "4px 10px",
            background: "#fff",
            border: "1px solid #e5e7eb",
            borderRadius: 6,
            fontSize: 11,
            fontWeight: 600,
            cursor: "pointer",
            color: "#374151",
          }}
        >
          Download
        </button>
      </div>
    </div>
  );
}

/* ------------------------------- Page --------------------------------- */

export default function ScreenshotsPage() {
  const [ready, setReady] = useState(false);
  const [sizeIdx, setSizeIdx] = useState(0);
  const [exporting, setExporting] = useState<string | null>(null);
  const exportRefs = useRef<(HTMLDivElement | null)[]>([]);

  useEffect(() => {
    preloadAllImages().then(() => setReady(true));
  }, []);

  const size = IPHONE_SIZES[sizeIdx];

  async function captureSlide(
    el: HTMLElement,
    w: number,
    h: number,
  ): Promise<string> {
    el.style.left = "0px";
    el.style.opacity = "1";
    el.style.zIndex = "-1";
    const opts = { width: w, height: h, pixelRatio: 1, cacheBust: true };
    // Double-call: first warms up fonts/images, second produces clean output.
    await toPng(el, opts);
    const dataUrl = await toPng(el, opts);
    el.style.left = "-9999px";
    el.style.opacity = "";
    el.style.zIndex = "";
    return dataUrl;
  }

  async function exportOne(i: number) {
    const el = exportRefs.current[i];
    if (!el) return;
    setExporting(`${i + 1}/${SLIDES.length}`);
    try {
      const dataUrl = await captureSlide(el, size.w, size.h);
      const a = document.createElement("a");
      a.href = dataUrl;
      a.download = `${String(i + 1).padStart(2, "0")}-${SLIDES[i].id}-${size.w}x${size.h}.png`;
      a.click();
    } finally {
      setExporting(null);
    }
  }

  async function exportAll() {
    for (let i = 0; i < SLIDES.length; i++) {
      setExporting(`${i + 1}/${SLIDES.length}`);
      const el = exportRefs.current[i];
      if (!el) continue;
      const dataUrl = await captureSlide(el, size.w, size.h);
      const a = document.createElement("a");
      a.href = dataUrl;
      a.download = `${String(i + 1).padStart(2, "0")}-${SLIDES[i].id}-${size.w}x${size.h}.png`;
      a.click();
      await new Promise((r) => setTimeout(r, 300));
    }
    setExporting(null);
  }

  if (!ready) {
    return (
      <div
        style={{
          minHeight: "100vh",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          fontFamily: "var(--font-sans), system-ui, sans-serif",
          color: "#6b7280",
        }}
      >
        Loading images…
      </div>
    );
  }

  return (
    <div
      style={{
        minHeight: "100vh",
        background: "#f3f4f6",
        position: "relative",
        overflowX: "hidden",
      }}
    >
      {/* Toolbar */}
      <div
        style={{
          position: "sticky",
          top: 0,
          zIndex: 50,
          background: "white",
          borderBottom: "1px solid #e5e7eb",
          display: "flex",
          alignItems: "center",
          fontFamily: "var(--font-sans), system-ui, sans-serif",
        }}
      >
        <div
          style={{
            flex: 1,
            display: "flex",
            alignItems: "center",
            gap: 12,
            padding: "12px 18px",
            overflowX: "auto",
            minWidth: 0,
          }}
        >
          <span
            style={{
              fontWeight: 700,
              fontSize: 14,
              whiteSpace: "nowrap",
              color: "#111",
            }}
          >
            MathBlocker · App Store Screenshots
          </span>
          <select
            value={sizeIdx}
            onChange={(e) => setSizeIdx(Number(e.target.value))}
            style={{
              fontSize: 12,
              border: "1px solid #e5e7eb",
              borderRadius: 6,
              padding: "5px 10px",
            }}
          >
            {IPHONE_SIZES.map((s, i) => (
              <option key={i} value={i}>
                {s.label} — {s.w}×{s.h}
              </option>
            ))}
          </select>
        </div>
        <div
          style={{
            flexShrink: 0,
            padding: "10px 18px",
            borderLeft: "1px solid #e5e7eb",
          }}
        >
          <button
            onClick={exportAll}
            disabled={!!exporting}
            style={{
              padding: "7px 20px",
              background: exporting ? "#93c5fd" : "#2563eb",
              color: "white",
              border: "none",
              borderRadius: 8,
              fontSize: 12,
              fontWeight: 600,
              cursor: exporting ? "default" : "pointer",
              whiteSpace: "nowrap",
            }}
          >
            {exporting ? `Exporting… ${exporting}` : "Export All"}
          </button>
        </div>
      </div>

      {/* Grid */}
      <div
        style={{
          padding: 24,
          display: "grid",
          gridTemplateColumns: "repeat(auto-fill, minmax(260px, 1fr))",
          gap: 20,
        }}
      >
        {SLIDES.map((slide, i) => (
          <ScreenshotPreview
            key={slide.id}
            slide={slide}
            cW={W}
            cH={H}
            index={i}
            onExport={exportOne}
          />
        ))}
      </div>

      {/* Offscreen export copies at true resolution. Each is absolutely
          positioned at left: -9999 directly inside the root overflowX: hidden
          wrapper, so captureSlide can flip it to left: 0 for the toPng call. */}
      {SLIDES.map((slide, i) => (
        <div
          key={slide.id}
          ref={(el) => {
            exportRefs.current[i] = el;
          }}
          style={{
            position: "absolute",
            top: 0,
            left: "-9999px",
            width: W,
            height: H,
            pointerEvents: "none",
          }}
        >
          {slide.component({ cW: W, cH: H })}
        </div>
      ))}
    </div>
  );
}
