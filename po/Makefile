
POT=./fantasdic.pot

RUBY=$(shell find ../lib -name '*.rb')

GLADE=$(shell find ../data -name '*.glade')

HEADERS=$(shell find .. -name '*.h')

PO=$(wildcard *.po)

$(POT): $(RUBY) $(GLADE) $(HEADERS)
	rm -f $(POT)
	@echo Updating PO template from Ruby files
	@rgettext --output=$(POT) $(RUBY)
	@echo Updating PO template from Glade files
	@xgettext --output=$(POT) --join-existing $(GLADE)
	@echo Updating PO template from header files
	@xgettext --output=$(POT) --join-existing --extract-all $(HEADERS)

$(PO): $(POT)
	msgmerge -U $@ $(POT)

po: $(POT)
	@echo Updating PO files
	@for po in $(PO); do \
		echo -n "$$po: "; \
		msgmerge -U $$po $(POT); \
	done

check:
	@echo Checking PO files
	@echo
	@for po in $(PO); do \
		echo "$$po: "; \
		msgfmt -cvv $$po -o /dev/null; \
		echo; \
	done

.PHONY: $(PO) po check

