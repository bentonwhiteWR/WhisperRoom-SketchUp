# GOAL

## Mission
Build revision 2 of the UT Health Sciences booth-renderings proposal PDF from the
18 renders in C:\Users\bento\Desktop\ProposalFiles\UTHealthSciences. Same layout
as rev 1; this revision adds a second booth in Room 1.

## Done means
- C:\Users\bento\Desktop\ProposalFiles\UTHealthSciences\UTHealthSciences-Booth-Renderings.pdf
  exists, US Letter portrait, one render per page, brand orange #ee6216, footer
  both sides on every page.
- Page order is Benton's: cover hero (Overview R) -> TopDownOverview -> then each
  room as render(s) -> booth dimension views -> RoomNOverview top-down LAST.
  Room 1 carries 1.1 and 1.2; Room 2 puts BoothDimensionsBackside before its
  top-down.
- Every dimension callout transcribed exactly from the render, never rounded or
  inferred. No prices, lead times or freight.
- The finished PDF is rasterised back with PyMuPDF and EVERY page plus EVERY
  bottom edge inspected.
- An explicit list of every caption line that was invented rather than read off a
  render or lifted from boilerplate.

## Now
Builder: build the pack per the whisperroom-proposal skill and
reference/proposal-playbook.md.

## Out of scope
- Overwriting anything in C:\Users\bento\Desktop\ProposalFiles\Saravanan Elangovan\.
- Prices, lead times, freight, STC or the word "soundproof".
- The MJP / desk overlay fix (separate, uncommitted at 1.19.13, awaiting Benton's
  SketchUp confirmation). Do not touch scripts/.

## History
- MJP orientation + 3/32" desk drop fixed in scripts/wr-overlays.rb, 1.19.13,
  uncommitted, awaiting Benton's confirmation on a live booth-link import.
