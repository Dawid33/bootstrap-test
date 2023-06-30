; returns a string of null character-separated preprocessing tokens and space characters
; this corresponds to translation phases 1-3 in the C89 standard
; each sequence of two or more spaces is replaced with a single space
; spaces around # and ## are removed
function split_into_preprocessing_tokens
	argument filename
	local fd
	local file_contents
	local pptokens
	local pptokens2
	local p
	local b
	local c
	local in
	local out
	local n
	local line_number
	
	fd = open_r(filename)
	file_contents = malloc(2000000)
	pptokens = malloc(2000000)
	p = file_contents
	:pptokens_read_loop
		n = syscall(0, fd, p, 4096)
		if n == 0 goto pptokens_read_loop_end
		p += n
		goto pptokens_read_loop
	:pptokens_read_loop_end
	p -= 1
	if *1p != 10 goto no_newline_at_end_of_file
	
	; okay we read the file. first, delete every backslash-newline sequence (phase 2)
	local newlines ; we add more newlines to keep line numbers right
	newlines = 1
	in = file_contents
	out = file_contents
	:backslashnewline_loop
		c = *1in
		if c == 0 goto backslashnewline_loop_end
		if c == 10 goto proper_newline_loop
		if c != '\ goto not_backslashnewline
			p = in + 1
			c = *1p
			if c != 10 goto not_backslashnewline
				in += 2 ; skip backlash and newline
				newlines += 1 ; add one additional newline the next time around to compensate
				goto backslashnewline_loop
		:not_backslashnewline
			*1out = *1in
			out += 1
			in += 1
			goto backslashnewline_loop
		:proper_newline_loop
			if newlines == 0 goto proper_newline_loop_end
			; output a newline
			*1out = 10
			out += 1
			newlines -= 1
			goto proper_newline_loop
		:proper_newline_loop_end
			newlines = 1
			in += 1
			goto backslashnewline_loop
	:backslashnewline_loop_end
	*1out = 0
	
	; @NONSTANDARD: this is where trigraphs would go
	
	; split file into preprocessing tokens, remove comments (phase 3)
	; we're still doing the trick with newlines, this time for ones inside comments
	; this is needed because the following is legal C:
	;   #include/*
	;     */<stdio.h>
	; and is not equivalent to:
	;   #include
	;     <stdio.h>
	newlines = 1
	in = file_contents
	out = pptokens
	line_number = 1
	:pptokens_loop
		c = *1in
		if c == 10 goto pptokens_newline_loop
		if c == 0 goto pptokens_loop_end
		if c == 32 goto pptoken_space
		if c == 9 goto pptoken_space
		b = isdigit(c)
		if b != 0 goto pptoken_number
		b = isalpha_or_underscore(c)
		if b != 0 goto pptoken_identifier
		b = str_startswith(in, .str_one_line_comment)
		if b != 0 goto pptoken_one_line_comment
		b = str_startswith(in, .str_comment_start)
		if b != 0 goto pptoken_comment
		; now we check for all the various operators and symbols in C
		
		if c == 59 goto pptoken_single_character ; semicolon
		if c == '( goto pptoken_single_character
		if c == ') goto pptoken_single_character
		if c == '[ goto pptoken_single_character
		if c == '] goto pptoken_single_character
		if c == '{ goto pptoken_single_character
		if c == '} goto pptoken_single_character
		if c == ', goto pptoken_single_character
		if c == '~ goto pptoken_single_character
		if c == '? goto pptoken_single_character
		if c == ': goto pptoken_single_character
		if c == '" goto pptoken_string_or_char_literal
		if c == '' goto pptoken_string_or_char_literal
		b = str_startswith(in, .str_lshift_eq)
		if b != 0 goto pptoken_3_chars
		b = str_startswith(in, .str_rshift_eq)
		if b != 0 goto pptoken_3_chars
		b = str_startswith(in, .str_eq_eq)
		if b != 0 goto pptoken_2_chars
		b = str_startswith(in, .str_not_eq)
		if b != 0 goto pptoken_2_chars
		b = str_startswith(in, .str_gt_eq)
		if b != 0 goto pptoken_2_chars
		b = str_startswith(in, .str_lt_eq)
		if b != 0 goto pptoken_2_chars
		b = str_startswith(in, .str_plus_plus)
		if b != 0 goto pptoken_2_chars
		b = str_startswith(in, .str_minus_minus)
		if b != 0 goto pptoken_2_chars
		b = str_startswith(in, .str_plus_eq)
		if b != 0 goto pptoken_2_chars
		b = str_startswith(in, .str_minus_eq)
		if b != 0 goto pptoken_2_chars
		b = str_startswith(in, .str_times_eq)
		if b != 0 goto pptoken_2_chars
		b = str_startswith(in, .str_div_eq)
		if b != 0 goto pptoken_2_chars
		b = str_startswith(in, .str_percent_eq)
		if b != 0 goto pptoken_2_chars
		b = str_startswith(in, .str_and_eq)
		if b != 0 goto pptoken_2_chars
		b = str_startswith(in, .str_or_eq)
		if b != 0 goto pptoken_2_chars
		b = str_startswith(in, .str_xor_eq)
		if b != 0 goto pptoken_2_chars
		b = str_startswith(in, .str_and_and)
		if b != 0 goto pptoken_2_chars
		b = str_startswith(in, .str_or_or)
		if b != 0 goto pptoken_2_chars
		b = str_startswith(in, .str_lshift)
		if b != 0 goto pptoken_2_chars
		b = str_startswith(in, .str_rshift)
		if b != 0 goto pptoken_2_chars
		b = str_startswith(in, .str_arrow)
		if b != 0 goto pptoken_2_chars
		b = str_startswith(in, .str_dotdotdot)
		if b != 0 goto pptoken_3_chars
		b = str_startswith(in, .str_hash_hash)
		if b != 0 goto pptoken_2_chars
		if c == '+ goto pptoken_single_character
		if c == '- goto pptoken_single_character
		if c == '* goto pptoken_single_character
		if c == '/ goto pptoken_single_character
		if c == '% goto pptoken_single_character
		if c == '& goto pptoken_single_character
		if c == '| goto pptoken_single_character
		if c == '^ goto pptoken_single_character
		if c == '> goto pptoken_single_character
		if c == '< goto pptoken_single_character
		if c == '! goto pptoken_single_character
		if c == '= goto pptoken_single_character
		if c == '# goto pptoken_single_character
		if c == '. goto pptoken_dot
		
		; " each non-white-space character that cannot be one of the above"
		goto pptoken_single_character
		
		:pptoken_one_line_comment
			; skip over comment
			in = memchr(in, 10)
			goto pptokens_loop
		:pptoken_comment
			; emit a space ("Each comment is replaced by one space character.")
			*1out = 32
			out += 1
			*1out = 0
			out += 1
			; skip over comment
			:pptoken_comment_loop
				b = str_startswith(in, .str_comment_end)
				if b != 0 goto pptoken_comment_loop_end
				c = *1in
				in += 1
				if c == 0 goto unterminated_comment
				if c == 10 goto pptoken_comment_newline
				goto pptoken_comment_loop
			:pptoken_comment_loop_end
			in += 2 ; skip */
			goto pptokens_loop
			:pptoken_comment_newline
				; keep line numbers correct
				newlines += 1
				goto pptoken_comment_loop
		:pptoken_dot
			; could just be a . or could be .3 -- we need to check if *(in+1) is a digit
			p = in + 1
			b = isdigit(*1p)
			if b != 0 goto pptoken_number
			; okay it's just a dot
			goto pptoken_single_character
		:pptoken_string_or_char_literal
			local delimiter
			local backslash
			delimiter = c
			backslash = 0
			*1out = c
			out += 1
			in += 1
			:pptoken_strchar_loop
				c = *1in
				*1out = c
				in += 1
				out += 1
				if c == '\ goto pptoken_strchar_backslash
				if c == 10 goto unterminated_string
				if c == 0 goto unterminated_string
				b = backslash
				backslash = 0
				if b == 1 goto pptoken_strchar_loop ; string can't end with an odd number of backslashes
				if c == delimiter goto pptoken_strchar_loop_end
				goto pptoken_strchar_loop
				:pptoken_strchar_backslash
					backslash ^= 1
					goto pptoken_strchar_loop
			:pptoken_strchar_loop_end
			*1out = 0
			out += 1
			goto pptokens_loop
		:pptoken_number
			c = *1in
			b = is_ppnumber_char(c)
			if b == 0 goto pptoken_number_end
			*1out = c
			out += 1
			in += 1
			if c == 'e goto pptoken_number_e
			if c == 'E goto pptoken_number_e
			goto pptoken_number
			:pptoken_number_e
				c = *1in
				if c == '+ goto pptoken_number_sign
				if c == '- goto pptoken_number_sign
				goto pptoken_number
			:pptoken_number_sign
				; special code to handle + - immediately following e
				*1out = c
				in += 1
				out += 1
				goto pptoken_number
			:pptoken_number_end
			*1out = 0
			out += 1
			goto pptokens_loop
		:pptoken_identifier
				c = *1in
				b = isalnum_or_underscore(c)
				if b == 0 goto pptoken_identifier_end
				*1out = c
				in += 1
				out += 1
				goto pptoken_identifier
			:pptoken_identifier_end
				*1out = 0
				out += 1
				goto pptokens_loop
		:pptoken_space
			; space character token
			*1out = 32
			in += 1
			out += 1
			*1out = 0
			out += 1
			goto pptokens_loop
		:pptoken_single_character
			; a single character preprocessing token, like {?}
			*1out = c
			in += 1
			out += 1
			*1out = 0
			out += 1
			goto pptokens_loop
		:pptoken_2_chars
			; two-character pptoken (e.g. ##)
			*1out = c
			in += 1
			out += 1
			*1out = *1in
			in += 1
			out += 1
			*1out = 0
			out += 1
			goto pptokens_loop
		:pptoken_3_chars
			; three-character pptoken (e.g. >>=)
			*1out = c
			in += 1
			out += 1
			*1out = *1in
			in += 1
			out += 1
			*1out = *1in
			in += 1
			out += 1
			*1out = 0
			out += 1
			goto pptokens_loop
		:pptokens_newline_loop
			if newlines == 0 goto pptokens_newline_loop_end
			; output a newline
			*1out = 10
			out += 1
			*1out = 0
			out += 1
			line_number += 1
			newlines -= 1
			goto pptokens_newline_loop
		:pptokens_newline_loop_end
			newlines = 1
			in += 1
			goto pptokens_loop	
	:pptokens_loop_end
	
	pptokens2 = file_contents ; repurpose file contents
	
	; replace each sequence of two or more spaces with a single space
	; "Whether each nonempty sequence of other white-space characters is
	; retained or replaced by one space character is implementation-defined." (C89 § 2.1.1.2)
	in = pptokens
	out = pptokens2
	:join_spaces_loop
		if *1in == 0 goto join_spaces_loop_end
		c = *1in
		pptoken_copy_and_advance(&in, &out)
		if c == 32 goto join_spaces
		goto join_spaces_loop
		:join_spaces
			pptoken_skip_spaces(&in)
			goto join_spaces_loop
	:join_spaces_loop_end
	*1out = 0
	
	; delete space surrounding ## and #
	; we want to delete spaces before # so that all preprocessor directives are at the start of the line
	;   (this makes recognizing them slightly easier)
	in = pptokens2
	out = pptokens
	:delete_hash_spaces_loop
		c = *1in
		if c == 0 goto delete_hash_spaces_loop_end
		if c == '# goto delete_hash_spaces_hash
		pptoken_copy_and_advance(&in, &out)
		goto delete_hash_spaces_loop
		
		:delete_hash_spaces_hash
			if out == pptokens goto copy_and_delete_spaces_after_hash ; little edge case
			p = out - 2
			if *1p != 32 goto copy_and_delete_spaces_after_hash ; no space before ##
			; space before #/##
			; remove it
			out -= 2
			*1out = 0
			:copy_and_delete_spaces_after_hash
			pptoken_copy_and_advance(&in, &out)
			pptoken_skip_spaces(&in)
			goto delete_hash_spaces_loop		
	:delete_hash_spaces_loop_end
	*1out = 0
	
	free(pptokens2)
	close(fd)
	return pptokens
	
	:unterminated_comment
		compile_error(filename, line_number, .str_unterminated_comment)
	:str_unterminated_comment
		string Unterminated comment.
		byte 0
	:unterminated_string
		compile_error(filename, line_number, .str_unterminated_string)
	:str_unterminated_string
		string Unterminated string or character literal.
		byte 0
	:no_newline_at_end_of_file
		compile_error(filename, 0, .str_no_newline_at_end_of_file)
	:str_no_newline_at_end_of_file
		string No newline at end of file.
		byte 0
; can the given character appear in a C89 ppnumber?
function is_ppnumber_char
	argument c
	if c == '. goto return_1
	if c < '0 goto return_0
	if c <= '9 goto return_1
	if c < 'A goto return_0
	if c <= 'Z goto return_1
	if c == '_ goto return_1
	if c < 'a goto return_0
	if c <= 'z goto return_1
	goto return_0

function print_pptokens
	argument pptokens
	local p
	p = pptokens
	:print_pptokens_loop
		if *1p == 0 goto print_pptokens_loop_end
		putc('{)
		puts(p)
		putc('})
		p += strlen(p)
		p += 1
		goto print_pptokens_loop
	:print_pptokens_loop_end
	putc(10)
	return

function pptoken_copy_and_advance
	argument p_in
	argument p_out
	local in
	local out
	in = *8p_in
	out = *8p_out
	out = strcpy(out, in)
	in = memchr(in, 0)
	*8p_in = in + 1
	*8p_out = out + 1
	return

function pptoken_skip
	argument p_in
	local in
	in = *8p_in
	in = memchr(in, 0)
	*8p_in = in + 1
	return

; reverse one pptoken
; don't call this on the first pptoken in the file
function pptoken_reverse
	argument p_in
	argument p_line_number
	local in
	in = *8p_in
	in -= 2
	:pptoken_rev_loop
		if *1in == 0 goto pptoken_rev_loop_end
		in -= 1
		goto pptoken_rev_loop
	:pptoken_rev_loop_end
	in += 1
	*8p_in = in
	if *1in != 10 goto return_0
	*8p_line_number -= 1
	return

; skip any space tokens here
function pptoken_skip_spaces
	argument p_in
	local in
	in = *8p_in
	:pptoken_skip_spaces_loop
		if *1in != 32 goto pptoken_skip_spaces_loop_end
		pptoken_skip(&in)
		goto pptoken_skip_spaces_loop
	:pptoken_skip_spaces_loop_end
	*8p_in = in
	return

; skip any whitespace tokens here
function pptoken_skip_whitespace
	argument p_in
	argument p_line_number
	local in
	in = *8p_in
	:skip_whitespace_loop
		if *1in == 10 goto skip_whitespace_incline
		if *1in != 32 goto skip_whitespace_loop_end
		pptoken_skip(&in)
		goto skip_whitespace_loop
		:skip_whitespace_incline
			*8p_line_number += 1
			pptoken_skip(&in)
			goto skip_whitespace_loop
	:skip_whitespace_loop_end
	*8p_in = in
	return

; go backwards before any spaces and newlines here
; don't do this for spaces at the start of the file
function pptoken_reverse_whitespace
	argument p_in
	argument p_line_number
	local in
	in = *8p_in
	:reverse_whitespace_loop
		if *1in == 10 goto reverse_whitespace
		if *1in != 32 goto reverse_whitespace_loop_end
		:reverse_whitespace
		pptoken_reverse(&in, p_line_number)
		goto reverse_whitespace_loop
	:reverse_whitespace_loop_end
	*8p_in = in
	return

function pptoken_skip_to_newline
	argument p_in
	local in
	in = *8p_in
	:pptoken_skip_to_newline_loop
		if *1in == 10 goto pptoken_skip_to_newline_end
		pptoken_skip(&in)
		goto pptoken_skip_to_newline_loop
	:pptoken_skip_to_newline_end
	*8p_in = in
	return
	
; phase 4:
; Preprocessing directives are executed and macro invocations are expanded.
; A #include preprocessing directive causes the named header or source file to be processed from phase 1 through phase 4, recursively.
function translation_phase_4
	argument filename
	argument input
	argument output
	local in
	local out
	local p
	local q
	local n
	local c
	local b
	local macro_name
	local line_number
	local temp_out
	
	out = output
	in = input
	
	; output line directive to put us in the right place for included files
	*1out = '$
	out += 1
	*1out = '1
	out += 1
	*1out = 32
	out += 1
	out = strcpy(out, filename)
	out += 1
		
	line_number = 0
	
	:phase4_line
		line_number += 1
		:phase4_line_noinc
		c = *1in
		if c == 0 goto phase4_end
		if c == '# goto pp_directive ; NOTE: ## cannot appear at the start of a line
		
		:process_pptoken
			c = *1in
			if c == 10 goto phase4_next_line
			b = isdigit(c)
			if b != 0 goto phase4_next_pptoken
			b = isalnum_or_underscore(c)
			if b != 0 goto phase4_try_replacements
			; (fallthrough)
		:phase4_next_pptoken
			pptoken_copy_and_advance(&in, &out)
			goto process_pptoken
		:phase4_next_line
			pptoken_copy_and_advance(&in, &out)
			goto phase4_line
	:phase4_try_replacements
		macro_replacement(filename, &line_number, &in, &out)
		goto process_pptoken
	:pp_directive
		pptoken_skip(&in) ; skip #
		pptoken_skip_spaces(&in)
		c = *1in
		if c == 10 goto phase4_next_line ; "null directive" C89 § 3.8.7
		b = str_equals(in, .str_error)
		if b != 0 goto pp_directive_error
		b = str_equals(in, .str_define)
		if b != 0 goto pp_directive_define
		b = str_equals(in, .str_undef)
		if b != 0 goto pp_directive_undef
		b = str_equals(in, .str_pragma)
		if b != 0 goto pp_directive_pragma
		b = str_equals(in, .str_line)
		if b != 0 goto pp_directive_line
		b = str_equals(in, .str_include)
		if b != 0 goto pp_directive_include
		b = str_equals(in, .str_ifdef)
		if b != 0 goto pp_directive_ifdef
		b = str_equals(in, .str_if)
		if b != 0 goto pp_directive_if
		b = str_equals(in, .str_elif)
		if b != 0 goto pp_directive_else ; treat elif the same as else at this point
		b = str_equals(in, .str_ifndef)
		if b != 0 goto pp_directive_ifndef
		b = str_equals(in, .str_else)
		if b != 0 goto pp_directive_else
		b = str_equals(in, .str_endif)
		if b != 0 goto pp_directive_endif
		goto unrecognized_directive
	:pp_directive_error
		puts(filename)
		putc(':)
		putn(line_number)
		puts(.str_directive_error)
		exit(1)
	:str_directive_error
		string : #error
		byte 10
		byte 0
	:pp_directive_line
		global 1000 dat_directive_line_text
		
		temp_out = &dat_directive_line_text
		macro_replacement_to_terminator(filename, &line_number, &in, &temp_out, 10)
		temp_out = &dat_directive_line_text
		
		; at this stage, we just turn #line directives into a nicer format:
		;    {$line_number filename} e.g.  {$77 main.c}
		local new_line_number
		pptoken_skip(&temp_out)
		pptoken_skip_spaces(&temp_out)
		new_line_number = stoi(temp_out)
		new_line_number -= 1 ; #line directive applies to the following line
		*1out = '$
		out += 1
		; copy line number
		p = itos(new_line_number)
		out = strcpy(out, p)
		*1out = 32
		out += 1
		pptoken_skip(&temp_out)
		pptoken_skip_spaces(&temp_out)
		if *1temp_out == 10 goto ppdirective_line_no_filename
		if *1temp_out != '" goto bad_line_directive
		; copy filename
		temp_out += 1
		filename = out
		out = memccpy(out, temp_out, '")
		*1out = 0
		out += 1
		goto ppdirective_line_cont
		:ppdirective_line_no_filename
		out = strcpy(out, filename)
		out += 1
		:ppdirective_line_cont
		line_number = new_line_number
		goto process_pptoken
	:pp_directive_undef
		pptoken_skip(&in)
		pptoken_skip_spaces(&in)
		macro_name = in
		pptoken_skip(&in)
		pptoken_skip_spaces(&in)
		if *1in != 10 goto bad_undef
		p = look_up_object_macro(macro_name)
		if p == 0 goto undef_not_object
		p -= 2
		*1p = '@ ; replace last character of macro name with @ to "undefine" it
		:undef_not_object
		p = look_up_function_macro(macro_name)
		if p == 0 goto undef_not_function
		p -= 2
		*1p = '@
		:undef_not_function
		goto process_pptoken
	:pp_directive_define
		local definition
		pptoken_skip(&in)
		pptoken_skip_spaces(&in)
		macro_name = in
		pptoken_skip(&in)
		c = *1in
		if c == '( goto function_macro_definition
			; it's an object-like macro, e.g. #define X 47
			pptoken_skip_spaces(&in)
			
			b = look_up_object_macro(macro_name)
			if b != 0 goto macro_redefinition
			
			p = object_macros + object_macros_size
			; copy name
			p = strcpy(p, macro_name)
			p += 1
			
			definition = in
			; copy contents
			memccpy_advance(&p, &in, 10) ; copy until newline
			
			if in == definition goto objmacro_cont
			
			; remove terminal space if there is one
			p -= 2
			if *1p == 32 goto objmacro_cont
			p += 2
			
			:objmacro_cont
			*1p = 255 ; replace newline with special "macro end" character
			p += 1
			object_macros_size = p - object_macros
			goto phase4_next_line
		:function_macro_definition
			; a function-like macro, e.g. #define JOIN(a,b) a##b
			local param_names
			local param_name
			local param_idx
			
			b = look_up_function_macro(macro_name)
			if b != 0 goto macro_redefinition
			
			param_names = malloc(4000)
			pptoken_skip(&in) ; skip opening parenthesis
			pptoken_skip_spaces(&in)
			param_name = param_names
			
			; macros with no arguments are legal for some reason
			if *1in == ') goto macro_params_loop_end
			
			:macro_params_loop
				c = *1in
				if c == 10 goto phase4_missing_closing_bracket
				b = isalpha_or_underscore(c)
				if b == 0 goto bad_macro_params
				param_name = strcpy(param_name, in)
				param_name += 1
				pptoken_skip(&in)
				pptoken_skip_spaces(&in)
				c = *1in
				if c == ') goto macro_params_loop_end
				if c != ', goto bad_macro_params
				pptoken_skip(&in) ; skip ,
				pptoken_skip_spaces(&in)
				goto macro_params_loop
			:macro_params_loop_end
			
			pptoken_skip(&in) ; skip )
			pptoken_skip_spaces(&in)
			
			p = function_macros + function_macros_size
			p = strcpy(p, macro_name)
			p += 1
			
			definition = in
			
			:fmacro_body_loop
				if *1in == 10 goto fmacro_body_loop_end
				param_name = param_names
				param_idx = 1
				; check if this token matches any of the parameter names
				:fmacro_param_check_loop
					if *1param_name == 0 goto fmacro_param_check_loop_end
					b = str_equals(in, param_name)
					if b != 0 goto fmacro_param_match
					param_name = memchr(param_name, 0)
					param_name += 1
					param_idx += 1
					goto fmacro_param_check_loop
				:fmacro_param_check_loop_end
					; it's not a parameter; just copy it out
					p = strcpy(p, in)
					p += 1
					pptoken_skip(&in)
					goto fmacro_body_loop
				:fmacro_param_match
					; a match!
					*1p = param_idx ; store the parameter index (1 = first argument) as a pptoken
					p += 2
					pptoken_skip(&in)
					goto fmacro_body_loop
			:fmacro_body_loop_end
			
			if in == definition goto fmacro_cont
			; remove terminal space if there is one
			p -= 2
			if *1p == 32 goto fmacro_cont
			p += 2
			:fmacro_cont
			
			*1p = 255
			p += 1
			function_macros_size = p - function_macros
			free(param_names)
			goto phase4_next_line
	:pp_directive_pragma
		; we don't have any pragmas
		compile_warning(filename, line_number, .str_unrecognized_pragma)
		pptoken_skip_to_newline(&in)
		goto process_pptoken
	:str_unrecognized_pragma
		string Unrecognized #pragma.
		byte 0
	:pp_directive_include
		global 1000 dat_directive_include_text
		local inc_filename
		temp_out = &dat_directive_include_text
		memset(temp_out, 0, 1000)
		inc_filename = malloc(4000)
		pptoken_skip(&in)
		macro_replacement_to_terminator(filename, &line_number, &in, &temp_out, 10)
		temp_out = &dat_directive_include_text
		pptoken_skip_spaces(&temp_out)
		if *1temp_out == '" goto pp_include_string
		if *1temp_out == '< goto pp_include_angle_brackets
		goto bad_include
	
		:pp_include_string
			p = inc_filename
			temp_out += 1
			:pp_include_string_loop
				c = *1temp_out
				temp_out += 1
				if c == '" goto pp_include_string_loop_end
				if c == 10 goto bad_include ; no terminating quote
				*1p = c
				p += 1
				goto pp_include_string_loop
			:pp_include_string_loop_end
			temp_out += 1 ; skip null separator after terminating quote
			pptoken_skip_spaces(&temp_out)
			if *1temp_out != 0 goto bad_include ; stuff after filename
			goto pp_include_have_filename
		:pp_include_angle_brackets
			p = inc_filename
			temp_out += 1
			:pp_include_angle_brackets_loop
				c = *1temp_out
				temp_out += 1
				if c == '> goto pp_include_angle_brackets_loop_end
				if c == 10 goto bad_include ; no terminating >
				if c == 0 goto pp_include_angle_brackets_loop ; separators between pptokens
				*1p = c
				p += 1
				goto pp_include_angle_brackets_loop
			:pp_include_angle_brackets_loop_end
			temp_out += 1 ; skip null separator after terminating >
			pptoken_skip_spaces(&temp_out)
			if *1temp_out != 0 goto bad_include ; stuff after filename
			goto pp_include_have_filename
		:pp_include_have_filename
		
		local included_pptokens
		included_pptokens = split_into_preprocessing_tokens(inc_filename)
		debug_puts(.str_including)
		debug_putsln(inc_filename)
		out = translation_phase_4(inc_filename, included_pptokens, out)
		free(included_pptokens)
		free(inc_filename)
		
		; output a line directive to put us back in the right place
		*1out = '$
		out += 1
		p = itos(line_number)
		out = strcpy(out, p)
		*1out = 32
		out += 1
		out = strcpy(out, filename)
		out += 1
		
		goto process_pptoken
		:str_including
			string Including
			byte 32
			byte 0
	:pp_directive_ifdef
		pptoken_skip(&in)
		pptoken_skip_spaces(&in)
		macro_name = in
		pptoken_skip(&in)
		pptoken_skip_spaces(&in)
		if *1in != 10 goto bad_ifdef
		p = look_up_object_macro(macro_name)
		if p != 0 goto process_pptoken ; macro is defined; keep processing
		p = look_up_function_macro(macro_name)
		if p != 0 goto process_pptoken ; macro is defined; keep processing
		preprocessor_skip_if(filename, &line_number, &in, &out, 0)
		goto phase4_line_noinc
	:pp_directive_ifndef
		pptoken_skip(&in)
		pptoken_skip_spaces(&in)
		macro_name = in
		pptoken_skip(&in)
		pptoken_skip_spaces(&in)
		if *1in != 10 goto bad_ifdef
		p = look_up_object_macro(macro_name)
		if p != 0 goto ifndef_skip ; macro is defined; skip
		p = look_up_function_macro(macro_name)
		if p != 0 goto ifndef_skip ; macro is defined; skip
		goto process_pptoken ; macro not defined; keep processing
		:ifndef_skip
		preprocessor_skip_if(filename, &line_number, &in, &out, 0)
		goto phase4_line_noinc
	:pp_directive_else
		; assume we got here from an if, so skip this
		pptoken_skip_to_newline(&in)
		; this might actually be an elif, so skip all the way to #endif.
		preprocessor_skip_if(filename, &line_number, &in, &out, 1)
		goto phase4_line_noinc
	:pp_directive_endif
		; assume we got here from an if/elif/else, just ignore it.
		pptoken_skip(&in)
		goto process_pptoken
	:pp_directive_if
		local if_pptokens
		local if_tokens
		local if_tokens_end
		local if_expr
		local def_name
		pptoken_skip(&in)
		pptoken_skip_spaces(&in)
		
		if_pptokens = malloc(8000)
		if_tokens = if_pptokens + 2500
		if_expr = if_tokens + 2500
		
		p = if_pptokens
		macro_replacement_to_terminator(filename, &line_number, &in, &p, 10)
		
		if_tokens_end = tokenize(if_pptokens, if_tokens, filename, line_number)
		; replace all identifiers with 0
		p = if_tokens
		:pp_if_idents0_loop
			if *1p == TOKEN_EOF goto pp_if_idents0_done
			if *1p == TOKEN_IDENTIFIER goto pp_if_replace_ident
			p += 16
			goto pp_if_idents0_loop
			:pp_if_replace_ident
				*1p = TOKEN_CONSTANT_INT
				p += 8
				*8p = 0
				p += 8
				goto pp_if_idents0_loop
		:pp_if_idents0_done
		;print_tokens(if_tokens, p)
		parse_expression(if_tokens, p, if_expr)
		;print_expression(if_expr)
		;putc(10)
		evaluate_constant_expression(p, if_expr, &b)
		if b == 0 goto pp_directive_if0
			goto pp_if_done
		:pp_directive_if0
			preprocessor_skip_if(filename, &line_number, &in, &out, 0)
			goto pp_if_done
		:pp_bad_defined
			token_error(p, .str_pp_bad_defined)
		:str_pp_bad_defined
			string Bad use of defined() in macro.
			byte 0
		:pp_if_done
		free(if_pptokens)
		goto phase4_line_noinc
	:unrecognized_directive
		compile_error(filename, line_number, .str_unrecognized_directive)
	:str_unrecognized_directive
		string Unrecognized preprocessor directive.
		byte 0
	:macro_redefinition
		; @NONSTANDARD:
		; technically not an error if it was redefined to the same thing, but it's
		; annoying to check for that
		compile_error(filename, line_number, .str_macro_redefinition)
	:str_macro_redefinition
		string Macro redefinition.
		byte 0
	:phase4_missing_closing_bracket
		compile_error(filename, line_number, .str_missing_closing_paren)
	:bad_macro_params
		compile_error(filename, line_number, .str_bad_macro_params)
	:str_bad_macro_params
		string Bad macro parameter list.
		byte 0
	:bad_undef
		compile_error(filename, line_number, .str_bad_undef)
	:str_bad_undef
		string Bad #undef.
		byte 0
	:bad_ifdef
		compile_error(filename, line_number, .str_bad_ifdef)
	:str_bad_ifdef
		string Bad #ifdef.
		byte 0
	:bad_line_directive
		compile_error(filename, line_number, .str_bad_line_directive)
	:str_bad_line_directive
		string Bad #line.
		byte 0
	:bad_include
		compile_error(filename, line_number, .str_bad_include)
	:str_bad_include
		string Bad #include.
		byte 0
	
	
	:phase4_end
		return out
	

; skip body of #if / #elif / #else. This will advance *p_in to:
;                       - right after the next #endif
;   OR if to_endif == 0 - right at the next unmatched #elif, replacing it with a #if
;   OR if to_endif == 0 - right after the next #else
; whichever comes first
; @NONSTANDARD: this doesn't properly handle #endif's, etc. which appear in a different file from their corresponding #if's.
; NOTE: p_out is needed for newlines
function preprocessor_skip_if
	argument filename
	argument p_line_number
	argument p_in
	argument p_out
	argument to_endif
	local in
	local out
	local p
	local b
	local line_number_start
	local prev_if_depth
	local if_depth
	in = *8p_in
	out = *8p_out
	if_depth = 0
	line_number_start = *8p_line_number
	:preprocessor_skip_if_loop
		prev_if_depth = if_depth
		if *1in == 0 goto no_matching_endif
		if *1in == 10 goto skip_if_newline
		if *1in == '# goto skip_if_hash
		pptoken_skip(&in)
		goto preprocessor_skip_if_loop
		:skip_if_newline
			*8p_line_number += 1
			pptoken_copy_and_advance(&in, &out)
			goto preprocessor_skip_if_loop
		:skip_if_hash
			p = in + 1
			if *1p != '# goto skip_if_directive
			; it's ##, not #
			pptoken_skip(&in)
			goto preprocessor_skip_if_loop
		:skip_if_directive
			pptoken_skip(&in) ; skip #
			b = str_equals(in, .str_else)
			if b != 0 goto skip_if_else
			b = str_equals(in, .str_endif)
			if b != 0 goto skip_if_endif
			b = str_equals(in, .str_elif)
			if b != 0 goto skip_if_elif
			b = str_equals(in, .str_if)
			if b != 0 goto skip_if_inc_depth
			b = str_equals(in, .str_ifdef)
			if b != 0 goto skip_if_inc_depth
			b = str_equals(in, .str_ifndef)
			if b != 0 goto skip_if_inc_depth
			goto preprocessor_skip_if_loop ; some unimportant directive
		:skip_if_elif
			if if_depth > 0 goto preprocessor_skip_if_loop
			if to_endif != 0 goto preprocessor_skip_if_loop
			; replace #elif with #if (kinda sketchy)
			*1in = '#
			in += 1
			*1in = 0
			in += 1
			*1in = 'i
			in += 1
			*1in = 'f
			in -= 3
			goto preprocessor_skip_if_loop_end
		:skip_if_inc_depth
			if_depth += 1
			goto preprocessor_skip_if_loop
		:skip_if_endif
			if_depth -= 1
			pptoken_skip(&in) ; skip endif
			if prev_if_depth > 0 goto preprocessor_skip_if_loop
			goto preprocessor_skip_if_loop_end
		:skip_if_else
			pptoken_skip(&in) ; skip else
			if to_endif != 0 goto preprocessor_skip_if_loop
			if prev_if_depth > 0 goto preprocessor_skip_if_loop
			goto preprocessor_skip_if_loop_end
	:preprocessor_skip_if_loop_end
	
	*8p_in = in
	*8p_out = out
	return
	
	:no_matching_endif
		compile_error(filename, line_number_start, .str_no_matching_endif)
	:str_no_matching_endif
		string #if/#elif/#else without matching #endif.
		byte 0
	
	
; returns a pointer to the replacement pptokens, or 0 if this macro is not defined
function look_up_macro
	argument macros
	argument name
	local p
	local b
	p = macros
	:macro_lookup_loop
		if *1p == 0 goto return_0
		b = str_equals(p, name)
		if b != 0 goto macro_lookup_loop_end
		; advance to next macro
		p = memchr(p, 255)
		p += 1
		goto macro_lookup_loop
	:macro_lookup_loop_end
	p = memchr(p, 0)
	p += 1
	return p

function look_up_object_macro
	argument name
	return look_up_macro(object_macros, name)

function look_up_function_macro
	argument name
	return look_up_macro(function_macros, name)

; replace macros at *p_in until terminator character is reached
function macro_replacement_to_terminator
	argument filename
	argument p_line_number
	argument p_in
	argument p_out
	argument terminator
	local in
	local out
	local b
	local lparen
	in = *8p_in
	out = *8p_out
	:macro_replacement_to_terminator_loop
		if *1in == terminator goto macro_replacement_to_terminator_loop_end
		b = str_equals(in, .str_defined)
		if b != 0 goto replace_defined
		macro_replacement(filename, p_line_number, &in, &out)
		goto macro_replacement_to_terminator_loop
		:replace_defined
			; @NONSTANDARD: technically this should only happen in #ifs but whatever
			pptoken_skip(&in)
			pptoken_skip_spaces(&in)
			lparen = 0
			if *1in != 40 goto defined_no_lparen
			lparen = 1
			pptoken_skip(&in)
			pptoken_skip_spaces(&in)
			:defined_no_lparen
			b = isalnum_or_underscore(*1in)
			if b == 0 goto bad_defined
			b = look_up_object_macro(in)
			if b != 0 goto defined_1
			b = look_up_function_macro(in)
			if b != 0 goto defined_1
			; not defined
			*1out = '0
			out += 1
			*1out = 0
			out += 1
			goto defined_cont
			:defined_1
			*1out = '1
			out += 1
			*1out = 0
			out += 1
			:defined_cont
			pptoken_skip(&in)
			if lparen == 0 goto macro_replacement_to_terminator_loop
			pptoken_skip_spaces(&in)
			if *1in != 41 goto bad_defined
			pptoken_skip(&in)
			goto macro_replacement_to_terminator_loop
	:macro_replacement_to_terminator_loop_end
	*8p_in = in
	*8p_out = out
	return
	:bad_defined
		compile_error(filename, *8p_line_number, .str_bad_defined)
	:str_bad_defined
		string Bad use of defined().
		byte 0

; @NONSTANDARD:
;  Macro replacement isn't handled properly in the following ways:
;    - function-like macros are not evaluated if the ( is not on the same line as the name of the macro
;    - if an object-like macro is defined to a function-like macro, the function-like macro is not evaluated, e.g.:
;        #define f(x) 2*x
;        #define g f
;        g(2)   => f(2) rather than 2*2
;    - when a macro refers to itself, it can be re-evaluated where that shouldn't happen, e.g.
;        #define z z[0]
;        #define f(x) x
;        f(f(z)) => z[0][0] rather than z[0]
;  These shouldn't be too much of an issue, though.
; replace pptoken(s) at *p_in into *p_out, advancing both
; NOTE: if *p_in starts with a function-like macro replacement, it is replaced fully,
;       otherwise this function only reads 1 token from *p_in
; NOTE: a pointer to the line number is passed in because function-like macro invocations
;       can span across multiple lines
function macro_replacement
	argument filename
	argument p_line_number
	argument p_in
	argument p_out
	; "banned" macros prevent #define x x from being a problem
	; C89 § 3.8.3.4
	; "If the name of the macro being replaced is found during this scan
	; of the replacement list, it is not replaced. Further, if any nested
	; replacements encounter the name of the macro being replaced, it is not replaced."
	global 2000 dat_banned_objmacros ; 255-terminated array of strings (initialized in main)
	local old_banned_objmacros_end
	global 2000 dat_banned_fmacros
	local old_banned_fmacros_end
	local banned_fmacros
	local banned_objmacros
	local b
	local c
	local p
	local q
	local replacement
	local in
	local out
	
	in = *8p_in
	out = *8p_out
	banned_objmacros = &dat_banned_objmacros
	banned_fmacros = &dat_banned_fmacros
	old_banned_objmacros_end = memchr(banned_objmacros, 255)
	old_banned_fmacros_end = memchr(banned_fmacros, 255)
	
	p = in
	pptoken_skip(&p)
	pptoken_skip_spaces(&p)
	if *1p == '( goto fmacro_replacement
	
	p = banned_objmacros
	
	:check_banned_objmacros_loop
		if *1p == 255 goto check_banned_objmacros_loop_end
		b = str_equals(in, p)
		if b != 0 goto no_replacement
		p = memchr(p, 0)
		p += 1
		goto check_banned_objmacros_loop
	:check_banned_objmacros_loop_end
	
	:objmacro_replacement
	b = str_equals(in, .str___FILE__)
	if b != 0 goto handle___FILE__
	b = str_equals(in, .str___LINE__)
	if b != 0 goto handle___LINE__
	b = str_equals(in, .str___DATE__)
	if b != 0 goto handle___DATE__
	b = str_equals(in, .str___TIME__)
	if b != 0 goto handle___TIME__
	b = str_equals(in, .str___STDC__)
	if b != 0 goto handle___STDC__
	
	replacement = look_up_object_macro(in)
	if replacement == 0 goto no_replacement
	
	; add this to list of banned macros
	p = strcpy(old_banned_objmacros_end, in)
	p += 1
	*1p = 255
	
	p = replacement
	pptoken_skip(&in) ; skip macro
	:objreplace_loop
		if *1p == 255 goto done_replacement
		macro_replacement(filename, p_line_number, &p, &out)
		goto objreplace_loop
	
	:fmacro_replacement
		p = banned_fmacros
		:check_banned_fmacros_loop
			if *1p == 255 goto check_banned_fmacros_loop_end
			b = str_equals(in, p)
			if b != 0 goto no_replacement
			p = memchr(p, 0)
			p += 1
			goto check_banned_fmacros_loop
		:check_banned_fmacros_loop_end
		
		replacement = look_up_function_macro(in)
		if replacement == 0 goto objmacro_replacement ; not a fmacro, check if it's an objmacro
		local macro_name
		macro_name = in
		
		pptoken_skip(&in) ; skip macro name
		pptoken_skip_spaces(&in)
		pptoken_skip(&in) ; skip opening bracket
		pptoken_skip_whitespace(&in, p_line_number)
		
		local arguments
		local fmacro_out
		local fmacro_out_start
		arguments = malloc(4000)
		fmacro_out_start = malloc(8000) ; direct fmacro output. this will need to be re-scanned for macros
		fmacro_out = fmacro_out_start
		
		; store the arguments (separated by 255-characters)
		p = arguments
		if *1in == ') goto fmacro_no_args
		:fmacro_arg_loop
			pptoken_skip_whitespace(&in, p_line_number)
			b = fmacro_arg_end(filename, p_line_number, in)
			b -= in
			; putnln(b)
			memcpy(p, in, b) ; copy the argument to its proper place
			p += b
			in += b ; skip argument
			pptoken_skip_whitespace(&in, p_line_number)
			c = *1in
			in += 2 ; skip , or )
			*1p = 255
			p += 1
			if c == ') goto fmacro_arg_loop_end
			goto fmacro_arg_loop
		:fmacro_no_args
			in += 2 ; skip )
			; (fallthrough)
		:fmacro_arg_loop_end
		*1p = 255 ; use an additional 255-character to mark the end (note: macro arguments may not be empty)
		
		; print arguments:
		; p += 1
		; p -= arguments
		; syscall(1, 1, arguments, p)
		
		p = replacement
		:freplace_loop
			if *1p == 255 goto freplace_loop_end
			if *1p < 32 goto fmacro_argument
			if *1p == '# goto freplace_hash_operator
			pptoken_copy_and_advance(&p, &fmacro_out)
			goto freplace_loop
			:freplace_hash_operator
				; handle paste and stringify operators
				; NOTE: we already ensured that there's no spaces following #,
				;       and no spaces surrounding ## in split_into_preprocessing_tokens
				p += 1
				if *1p == '# goto freplace_hashhash_operator
				
				; stringify operator
				p += 1 ; skip null separator following #
				q = fmacro_get_arg(filename, p_line_number, arguments, *1p)
				*1fmacro_out = '"
				fmacro_out += 1
				:fmacro_stringify_loop
					c = *1q
					q += 1
					if c == 255 goto fmacro_stringify_loop_end
					if c == '\ goto fmacro_stringify_escape
					if c == '" goto fmacro_stringify_escape
					if c == 10 goto fmacro_stringify_space ; replace newline with space
					if c == 32 goto fmacro_stringify_space
					if c == 0 goto fmacro_stringify_loop
					:fmacro_stringify_emit
						*1fmacro_out = c
						fmacro_out += 1
						goto fmacro_stringify_loop
					:fmacro_stringify_escape
						*1fmacro_out = '\
						fmacro_out += 1
						goto fmacro_stringify_emit
					:fmacro_stringify_space
						b = fmacro_out - 1
						if *1b == 32 goto fmacro_stringify_loop ; don't emit two spaces in a row
						*1fmacro_out = 32
						fmacro_out += 1
						goto fmacro_stringify_loop
						
				:fmacro_stringify_loop_end
				*1fmacro_out = '"
				fmacro_out += 1
				*1fmacro_out = 0
				fmacro_out += 1
				p += 2 ; skip arg idx & null separator
				goto freplace_loop
				
			:freplace_hashhash_operator
				; the paste operator (e.g. #define JOIN(a,b) a##b)
				; wow! surprisingly simple!
				fmacro_out -= 1
				pptoken_skip(&p)
				goto freplace_loop
		:freplace_loop_end
		
		; add this to list of banned macros
		; it's important that we do this now and not earlier because this is valid:
		;  #define f(x) x x
		;  const char *s = f(f("a"));  /* this preprocesses to  s = "a" "a" "a" "a" */
		p = strcpy(old_banned_fmacros_end, macro_name)
		p += 1
		*1p = 255
		
		fmacro_out = fmacro_out_start
		:frescan_loop
			if *1fmacro_out == 0 goto frescan_loop_end
			macro_replacement(filename, p_line_number, &fmacro_out, &out)
			goto frescan_loop
		:frescan_loop_end
		
		free(arguments)
		free(fmacro_out_start)
		goto done_replacement
		
	:fmacro_argument
		q = p + 3 ; skip these characters: arg idx, null separator, first '#'
		if *1q == '# goto fmacro_argument_no_rescan ; this argument is immediately followed by ## so it shouldn't be scanned for replacements
		q = p - 2 ; skip these characters: null separator, second '#'
		if *1q == '# goto fmacro_argument_no_rescan ; this argument is immediately preceded by ##
		; write argument to *fmacro_out, performing any necessary macro substitutions
		q = fmacro_get_arg(filename, p_line_number, arguments, *1p)
		:fmacro_arg_replace_loop
			macro_replacement(filename, p_line_number, &q, &fmacro_out)
			if *1q != 255 goto fmacro_arg_replace_loop
		p += 2 ; skip arg idx & null separator
		goto freplace_loop
		
		:fmacro_argument_no_rescan
			q = fmacro_get_arg(filename, p_line_number, arguments, *1p)
			fmacro_out = memccpy(fmacro_out, q, 255)
			*1fmacro_out = 0
			p += 2 ; skip arg idx & null separator
			goto freplace_loop
			
	:no_replacement
		pptoken_copy_and_advance(&in, &out)
		; (fallthrough)
	:done_replacement	
		*8p_in = in
		*8p_out = out
		; unban any macros we just banned
		*1old_banned_objmacros_end = 255
		*1old_banned_fmacros_end = 255
		return
	
	:handle___FILE__
		pptoken_skip(&in)
		*1out = '"
		out += 1
		out = strcpy(out, filename)
		*1out = '"
		out += 1
		*1out = 0
		out += 1
		goto done_replacement
	:handle___LINE__
		pptoken_skip(&in)
		p = itos(*8p_line_number)
		out = strcpy(out, p)
		out += 1
		goto done_replacement
	:handle___DATE__
		pptoken_skip(&in)
		out = strcpy(out, .str_compilation_date)
		out += 1
		goto done_replacement
	:handle___TIME__
		pptoken_skip(&in)
		out = strcpy(out, .str_compilation_time)
		out += 1
		goto done_replacement
	:handle___STDC__
		pptoken_skip(&in)
		out = strcpy(out, .str_stdc)
		out += 1
		goto done_replacement
	:str_compilation_date
		; "If the date of translation is not available, an implementation-defined valid date shall be supplied." C89 § 3.8.8
		string "Jan 01 1970"
		byte 0
	:str_compilation_time
		; "If the time of translation is not available, an implementation-defined valid time shall be supplied." C89 § 3.8.8
		string "00:00:00"
		byte 0
	:str_stdc
		; (see @NONSTANDARD) a bit of a lie, but oh well
		string 1
		byte 0
	
		
function fmacro_get_arg
	argument filename
	argument p_line_number
	argument arguments
	argument arg_idx
	:fmacro_argfind_loop
		if *1arguments == 255 goto fmacro_too_few_arguments
		if arg_idx == 1 goto fmacro_arg_found
		arguments = memchr(arguments, 255)
		arguments += 1
		arg_idx -= 1
		goto fmacro_argfind_loop
	:fmacro_arg_found
	return arguments
	:fmacro_too_few_arguments
		compile_error(filename, *8p_line_number, .str_fmacro_too_few_arguments)
	:str_fmacro_too_few_arguments
		string Too few arguments to function-like macro.
		byte 0

function fmacro_arg_end
	argument filename
	argument p_line_number
	argument in
	local bracket_depth
	bracket_depth = 1
	:fmacro_arg_end_loop
		if *1in == 0 goto fmacro_missing_closing_bracket
		if *1in == '( goto fmacro_arg_opening_bracket
		if *1in == ') goto fmacro_arg_closing_bracket
		if *1in == 10 goto fmacro_arg_newline
		if *1in == ', goto fmacro_arg_potential_end
		pptoken_skip(&in)
		goto fmacro_arg_end_loop
		:fmacro_arg_potential_end
			if bracket_depth == 1 goto fmacro_arg_end_loop_end
			pptoken_skip(&in)
			goto fmacro_arg_end_loop
		:fmacro_arg_opening_bracket
			bracket_depth += 1
			pptoken_skip(&in)
			goto fmacro_arg_end_loop
		:fmacro_arg_closing_bracket
			bracket_depth -= 1
			if bracket_depth == 0 goto fmacro_arg_end_loop_end
			pptoken_skip(&in)
			goto fmacro_arg_end_loop
		:fmacro_arg_newline
			*8p_line_number += 1
			pptoken_skip(&in)
			goto fmacro_arg_end_loop
	:fmacro_arg_end_loop_end
	pptoken_reverse(&in, p_line_number)
	pptoken_reverse_whitespace(&in, p_line_number)
	pptoken_skip(&in)
	
	return in
	
	:fmacro_missing_closing_bracket
		compile_error(filename, *8p_line_number, .str_missing_closing_paren)
	
function print_object_macros
	print_macros(object_macros)
	return

function print_function_macros
	print_macros(function_macros)
	return
	
function print_macros
	argument macros
	local p
	local c
	p = macros
	:print_macros_loop
		if *1p == 0 goto return_0 ; done!
		puts(p)
		putc(':)
		putc(32)
		p = memchr(p, 0)
		p += 1
		:print_replacement_loop
			c = *1p
			if c == 255 goto print_replacement_loop_end
			if c < 32 goto print_macro_param
			putc('{)
			puts(p)
			putc('})
			p = memchr(p, 0)
			p += 1
			goto print_replacement_loop
			:print_macro_param
				putc('{)
				putc('#)
				putn(c)
				putc('})
				p += 2
				goto print_replacement_loop
		:print_replacement_loop_end
			p += 1
			fputc(1, 10)
			goto print_macros_loop

	
