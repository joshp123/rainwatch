# Written by AI on 2026.11.18 by model claude fable 5.2. Every screen of the iPhone proposal as HTML for Paper. See ../README.md.
set -e
cd "$(dirname "$0")"
mkdir -p /tmp/rainwatch-iphone-paper
export V=${V:--c}   # Paper keeps a picture by its file name: change V when the pictures change
G() { n=$1; shift; uv run --with playwright python gen_paper.py "$n$V" "$@"; }
S="run=saved"
G open index.html "$S&place=0&play=rest" "#phone"
G in20 index.html "$S&place=0&still=20" "#phone"
G in35 index.html "$S&place=0&still=35" "#phone"
G raining index.html "$S&place=1&play=rest" "#phone"
G dry index.html "$S&at=51.92,4.48,Rotterdam&play=rest" "#phone"
G light index.html "$S&place=2&theme=light&play=rest" "#phone"
G nl index.html "$S&place=0&lang=nl&still=20" "#phone"
G old index.html "$S&place=0&age=35&play=rest" "#phone"
G apple index.html "$S&at=53.10,6.25,London&source=apple" "#phone"
for i in 0 1 3 4 5; do G lock$i widgets.html "" ".lock" $i; done
for i in 0 1 3 4 5 6 7; do G small$i widgets.html "" ".small" $i; done
for i in 0 1 3 4; do G medium$i widgets.html "" ".medium" $i; done
G nllock widgets.html "lang=nl" ".lock" 0
G nlsmall widgets.html "lang=nl" ".small" 1
G nlmedium widgets.html "lang=nl" ".medium" 0
for v in map line ring; do uv run --with playwright python shot.py /tmp/rainwatch-iphone-paper/dropped-$v$V.png "$S&place=0&v=$v&play=rest" 800; done
python3 build.py
