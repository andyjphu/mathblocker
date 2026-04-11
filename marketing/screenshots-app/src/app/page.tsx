"use client";

import { useEffect, useLayoutEffect, useRef, useState } from "react";
import { toPng } from "html-to-image";

/* ----------------------------- Constants ------------------------------ */

// Design canvas — iPhone 6.7" (1284 × 2778). This matches the largest
// allowed Apple App Store portrait export, so the 6.7" export is 1:1
// and the 6.5" export downscales by a negligible ~3%.
const W = 1284;
const H = 2778;

const IPHONE_SIZES = [
  { label: '6.7"', w: 1284, h: 2778 },
  { label: '6.5"', w: 1242, h: 2688 },
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
   All phone positioning lives here. Two configs:

   PLACEMENT       — the 5 main slides. Keyed by slide id.
   SPLIT_PLACEMENT — the 3 tilted split pairs. Keyed by pair id.

   Every slide reads its phone values from one of these objects. Tweak the
   numbers here, save, hot-reload picks it up.

   ---- Main slide knobs (PLACEMENT) ----
   - widthPct:      phone LAYOUT size as % of canvas width (77 = 77%).
                    This is the baseline "how big is this phone" dial.
   - translateXPct: shift phone sideways by % of canvas width
                    (positive = right, negative = left, omit = centered)
   - translateYPct: push phone down by % of its OWN height
                    (14 = 14% of the phone hangs off the bottom)
   - scale:         CSS scale() multiplier on top of widthPct
                    (1 = none, 0.9 = 10% smaller, 1.1 = 10% bigger)
   - rotateDeg:     rotate the phone in degrees (omit = upright)

   Example — slide 2 smaller, nudged right, slightly scaled, tilted:
     block: {
       widthPct: 72, translateXPct: 8, translateYPct: 14,
       scale: 0.95, rotateDeg: -4,
     }

   ---- Split pair knobs (SPLIT_PLACEMENT) ----
   Each pair key (e.g. "split-30") is shared by its two halves, so
   editing one key affects both slides of that pair.

   - widthPct:         phone width as % of canvas width
                       (splits use 65 by default since rotation enlarges
                       the bounding box — crank too high and corners
                       crash into the top/bottom of the canvas)
   - verticalCenterPct: where the phone's center sits on the seam
                       (0 = top of canvas, 100 = bottom, 55 = slightly
                       below center)
   - angleDeg:         rotation. 0 = straight-vertical split, 30 = subtle
                       editorial lean, 45 = full diagonal, 60 = near
                       horizontal
   - scale:            scale() multiplier (default 1)
   - translateXPct:    nudge from the seam in % of canvas width
                       (same value in both halves shifts the whole phone;
                       opposite values break the seam illusion)
   - translateYPct:    extra vertical nudge from verticalCenterPct,
                       in % of canvas height
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

type SplitPlacement = {
  widthPct: number;
  verticalCenterPct: number;
  angleDeg: number;
  scale?: number;
  translateXPct?: number;
  translateYPct?: number;
  // How much panel B should sit HIGHER than panel A, in % of canvas
  // height. Compensates for the visible gap between adjacent screenshots
  // in the App Store carousel so a tilted phone feels continuous across
  // the seam. Applied as the outermost (last) transform on panel B only.
  abOffsetYPct?: number;
};

const SPLIT_PLACEMENT: Record<string, SplitPlacement> = {
  "split-30": { widthPct: 115, verticalCenterPct: 50, translateXPct: -25, angleDeg: 30, abOffsetYPct:3 },
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

// Shared phone style for the tilted split halves — center anchored to
// the seam at left:100% (left half) or left:0% (right half), vertical
// position from verticalCenterPct. translate(-50%, -50%) lands the
// phone's center on that anchor, then scale and rotate are applied.
// For panel B, abOffsetYPct lifts the whole phone up as the final
// (outermost) transform to compensate for the carousel gap.
function splitPhoneStyle(
  p: SplitPlacement,
  half: "left" | "right",
  cH: number,
): React.CSSProperties {
  const tx = p.translateXPct ?? 0;
  const ty = p.translateYPct ?? 0;
  const sc = p.scale ?? 1;
  const abo = p.abOffsetYPct ?? 0;
  const anchorX = half === "left" ? "100%" : "0%";
  // Panel A stays put. Panel B lifts up by abo% of canvas height.
  // Negative Y = upward in screen coordinates.
  const outerYPx = half === "right" ? -(abo * cH) / 100 : 0;
  return {
    position: "absolute",
    width: `${p.widthPct}%`,
    left: `calc(${anchorX} + ${tx}%)`,
    top: `calc(${p.verticalCenterPct}% + ${ty}%)`,
    // Leftmost operation in a CSS transform chain is applied LAST. The
    // translateY(outerYPx) nudge therefore fires after rotate/scale/center,
    // which is what "applied as last transform" means here.
    transform: `translateY(${outerYPx}px) translate(-50%, -50%) scale(${sc}) rotate(${p.angleDeg}deg)`,
    transformOrigin: "center",
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
  tag,
  fgColor = INK,
  align = "center",
  maxWidth = "86%",
  headlineScale = 1,
  tagScale = 1,
  tagOpacity = 0.72,
}: {
  cW: number;
  headline: React.ReactNode;
  tag?: React.ReactNode;
  fgColor?: string;
  align?: "left" | "center" | "right";
  maxWidth?: string;
  headlineScale?: number;
  tagScale?: number;
  tagOpacity?: number;
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
          fontSize: cW * 0.098 * headlineScale,
          fontWeight: 400,
          lineHeight: 1.0,
          letterSpacing: -cW * 0.0012,
          color: fgColor,
        }}
      >
        {headline}
      </div>
      {tag && (
        <div
          style={{
            fontFamily: "var(--font-serif), Georgia, serif",
            fontSize: cW * 0.038 * tagScale,
            fontStyle: "italic",
            fontWeight: 400,
            lineHeight: 1.25,
            letterSpacing: -cW * 0.0004,
            color: fgColor,
            marginTop: cW * 0.022,
            opacity: tagOpacity,
          }}
        >
          {tag}
        </div>
      )}
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
            top: cH * 0.075,
            left: 0,
            right: 0,
          }}
        >
          <Caption
            cW={cW}
            headline={
              <>
                so earn
                <br />
                it back
              </>
            }
            fgColor="#F6EEE0"
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
                interrupt your
                <br />
                brainrot
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
          background: `linear-gradient(170deg, ${ESPRESSO} 0%, ${ESPRESSO_2} 60%, #3A2615 100%)`,
        }}
      >
        <SoftBlob color={GOLD} size="70%" top="-20%" left="-20%" opacity={0.18} />
        <SoftBlob color={TERRA} size="55%" top="35%" left="60%" opacity={0.15} />
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
                watch your
                <br />
                screen time
                <br />
                go down
              </>
            }
            fgColor="#F6EEE0"
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
            maxWidth="96%"
            tagScale={1.25}
            headline={
              <>
                solve academic
                <br />
                math problem sets
              </>
            }
            tag={
              <>
                you can even download AIME, AMC, Putnam.
                <br />
                good luck with that.
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

   Every split reads its geometry from SPLIT_PLACEMENT[pairKey] at the
   top of this file. The factory below just wires it into a slide. */

function makeTiltedSplit(
  pairKey: string,
  half: "left" | "right",
  headline: React.ReactNode,
  opts: {
    tag?: React.ReactNode;
    captionPos?: "top" | "bottom";
    // Delta applied to the caption's distance from its edge, in % of
    // canvas height. Negative = shift caption up, positive = shift down.
    // Works for both captionPos "top" and "bottom".
    captionOffsetYPct?: number;
    headlineScale?: number;
    tagScale?: number;
    tagOpacity?: number;
  } = {},
): SlideDef {
  const p = SPLIT_PLACEMENT[pairKey];
  const captionPos = opts.captionPos ?? "top";
  const captionOffset = opts.captionOffsetYPct ?? 0;
  return {
    id: `${pairKey}-${half === "left" ? "a" : "b"}`,
    component: ({ cW, cH }) => {
      // Default distance from the caption's edge: 6% of canvas height.
      // For top-anchored captions, a negative offset pulls the caption
      // toward the top (smaller `top`). For bottom-anchored, a negative
      // offset pulls it visually up = farther from the bottom edge =
      // LARGER `bottom` value, which is why we subtract.
      const topPx = cH * (0.06 + captionOffset / 100);
      const bottomPx = cH * (0.06 - captionOffset / 100);
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
          <Phone
            src={img("/screenshots/shield.png")}
            alt="Shield"
            style={splitPhoneStyle(p, half, cH)}
          />
          <div
            style={{
              position: "absolute",
              left: cW * 0.07,
              right: cW * 0.07,
              ...(captionPos === "top"
                ? { top: topPx }
                : { bottom: bottomPx }),
              zIndex: 20,
            }}
          >
            <Caption
              cW={cW}
              headline={headline}
              tag={opts.tag}
              headlineScale={opts.headlineScale}
              tagScale={opts.tagScale}
              tagOpacity={opts.tagOpacity}
              align={half === "left" ? "left" : "right"}
              maxWidth="100%"
            />
          </div>
        </div>
      );
    },
  };
}

const slideSplit30L = makeTiltedSplit(
  "split-30",
  "left",
  <>
    interrupt
    <br />
    doomscrolling
    <br />
    with {"\u201C"}math{"\u201D"}
  </>,
  {
    captionOffsetYPct: -2.5,
  },
);
const slideSplit30R = makeTiltedSplit(
  "split-30",
  "right",
  <>
    make boredom
    <br />
    fun again
  </>,
  {
    captionPos: "bottom",
    headlineScale: 2,
    tagScale: 2.25,
    tagOpacity: 0.61,
    tag: (
      <>
        (or scrolling worse,
        <br />
        whatever stops
        <br />
        your addiction)
      </>
    ),
  },
);

const SLIDES: SlideDef[] = [
  slide1,
  slide2,
  slide3,
  slide4,
  slide5,
  slideSplit30L,
  slideSplit30R,
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
