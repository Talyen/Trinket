# Launch animation artwork

The approved loading-screen slime uses the original green enemy artwork as its
reference. Both source sheets were created with the built-in imagegen tool and
retained unchanged here. The fox poses on the leaf source sheet are unused.

The small, authored transparent PNG layers in `Trinket/LaunchArtwork/` were exported
from the approved preview at three times their displayed dimensions. They ship as
a separate folder resource, outside the curated combatant art pipeline. Animation,
face placement, and the loading clock live in `LaunchLoadingDecoration.swift` and
`LaunchWarmupView.swift`; do not regenerate these layers through the HEIC pipeline.

## Slime source prompt

Reference: `Raw Assets/Enemies/Slime.jpeg`.

Use case: stylized-concept. Create an animation-layer asset sheet on genuinely
transparent background inspired by the reference green slime for Trinket's loading
screen. Match its illustrated storybook ink outlines, yellow-lime glossy top, deep
emerald lower jelly, round dome and soft flattened bottom. No forest, scenery,
text, checkerboard, ground, shadow or labels. Square canvas. TWO separated
non-overlapping components: LEFT HALF contains one large FACELESS slime body
(absolutely no eyes or mouth on the body), entirely within left 48% of canvas,
centered vertically. RIGHT HALF contains ONLY the matching facial features together
as one transparent overlay: two big dark oval eyes with cream glossy highlights
and a tiny curved w-shaped smile beneath, arranged at same proportions as reference,
centered in right half. No green backing behind face. Body and face should compose
into the original cute slime when face overlay placed over middle of body. Keep
both components safely away from all edges and from each other with clear
transparent gutter. This is a high quality clean game illustration, not 3D render.
No extra characters, arms, legs, props or facial expressions. Smooth alpha edges.

## Leaf source prompt

Reference: `Raw Assets/Companions/Fox.jpeg`.

Create a polished 2D animation sprite sheet inspired by the provided Trinket FOX
companion illustration. Preserve the character: vivid orange angular storybook
fur, black ink contour, cream muzzle/chest and huge fluffy cream-tipped tail, long
dark brown paws, tall triangular ears, warm expressive amber eyes. Adapt to a small
charming side-profile FOX FACING RIGHT, running right, tail trailing to the LEFT.
Natural fox anatomy, not chibi. Genuine transparent background everywhere. No
scenery, labels, text, ground, shadow, checkerboard or borders. Square canvas
divided into exactly 3 equal columns and 3 equal rows, nine well-separated cells
with generous transparent gutters. All foxes share identical identity, lighting,
scale, right-facing orientation, and baseline; keep ALL anatomy entirely within
each cell. First six cells (read left to right, top to bottom in first TWO rows)
show SIX successive full-body poses of a coherent fox running cycle: forepaws
extended contact; compression/recoil; hind-leg push-off; airborne collected paws;
airborne extended forelegs; foreleg reach toward next contact. Show clear changing
limb positions, slight back flex, and tail arc; not six duplicates. Cell 7 (bottom
left) shows same fox in calm standing idle pose facing right, all four paws
grounded. Cell 8 (bottom middle) contains only ONE small ochre-gold autumn leaf with
dark ink outline and fine vein. Cell 9 (bottom right) contains only ONE small
forest-green leaf with dark ink outline and fine vein. The leaves have no fox or
other objects. Fox artwork should be crisp, simplified enough to read at 80px wide,
high quality game art matching reference. All sprites isolated with clean alpha
and generous padding. Do not add characters, props, words or visual grid lines.
