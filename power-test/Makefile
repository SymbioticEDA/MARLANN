all: power-usage.pdf

# $@ The file name of the target of the rule.rule
# $< first pre requisite
# $^ names of all preerquisites

power-usage.pdf: template.tex README.md
	pandoc --template=template.tex --variable mainfont="DejaVu Sans" \
    --variable sansfont="DejaVu Sans" --variable fontsize=14pt \
    --latex-engine=xelatex --variable geometry:margin=2cm \
    README.md -o $@

clean:
	rm README.md

.PHONY: all clean
