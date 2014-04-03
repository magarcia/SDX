# Makefile
VERSION     = 0.0.1
LIBDIR      = `erl -eval 'io:format("~s~n", [code:lib_dir()])' -s init stop -noshell`
ERLC        = erlc
ERLC_FLAGS  = -Wall +debug_info -I$(LIBDIR)
ERL         = erl
SRCS    	= $(wildcard *.erl)
OBJS    	= ${SRCS:.erl=.beam}
APP_NAME	= S2
EBIN 		= ebin

all: $(EBIN) compile
run: all start


compile: $(SRCS)
	@echo Compiling erlang files
	@$(ERLC) $(ERLC_FLAGS) -o $(EBIN) $^

docs:
	@echo Generating documentation from srcs
	@erl -noshell -run edoc_run application "'$(APP_NAME)'" '"."' '[{def,{vsn,"$(VERSION)"}}]'

start:
	# (cd $(EBIN); erl -eval -sname Fry 'muty:start(lock1, 1000, 2000).' -noshell)
	env  /bin/sh -c "for i in Zoidberg Leela Bender Hermes AmyWong Zapp Kif Calculon Farnsworth Donbot Elzar Flexo Hypnotoad RobotDevil RobotSanta Scruffy; do echo \"erl -eval -sname $i 'muty_split:start({myserver, Fry@`hostname`}).\"; done"
	# (cd $(EBIN); erl -eval -sname Fry 'muty_split:start(lock1, 1000, 2000).')

$(EBIN):
	@mkdir -p $(EBIN)

clean:
	@echo Clean docs and complied files
	@rm -rf $(EBIN)/ erl_crash.dump
	@rm -rf doc

.PHONY: clean compile start all edoc $(EBIN)