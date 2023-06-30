global file_list ; initialized in main -- null-separated 255-terminated array of strings

; get the name of the file with the given index
function file_get
	argument idx
	local p
	p = file_list
	:file_get_loop
		if idx == 0 goto file_got
		if *1p == 255 goto file_uhoh
		idx -= 1
		p = memchr(p, 0)
		p += 1
		goto file_get_loop
	:file_got
	return p
	:file_uhoh
	puts(.str_bad_file_index)
	exit(1)
	:str_bad_file_index
		string Bad file index. This shouldn't happen.
		byte 10
		byte 0
	
; get the index of the given file, returns -1 if file does not exist
function file_get_index
	argument filename
	local p
	local b
	local i
	p = file_list
	i = 0
	:file_get_index_loop
		if *1p == 255 goto return_minus1
		b = str_equals(p, filename)
		if b != 0 goto file_found
		i += 1
		p = memchr(p, 0)
		p += 1
		goto file_get_index_loop
	:file_found
	return i
	
; add to list of files if not already there
function file_add
	argument filename
	local p
	p = file_get_index(filename)
	if p != -1 goto return_0
	p = memchr(file_list, 255)
	p = strcpy(p, filename)
	p += 1
	*1p = 255
	return

; return keyword ID associated with str, or 0 if it's not a keyword
function get_keyword_id
	argument keyword_str
	local p
	local c
	local b
	p = .keyword_table
	:keyword_id_loop
		c = *1p
		if c == 255 goto no_such_keyword_str
		p += 1
		b = str_equals(keyword_str, p)
		if b != 0 goto got_keyword_id
		p = memchr(p, 0)
		p += 1
		goto keyword_id_loop
	:no_such_keyword_str
	return 0
	:got_keyword_id
	return c

; get string associated with keyword id, or "@BAD_KEYWORD_ID" if it's not a keyword
function get_keyword_str
	argument keyword_id
	local p
	local c
	local b
	p = .keyword_table
	:keyword_str_loop
		c = *1p
		if c == 255 goto no_such_keyword_id
		if c == keyword_id goto found_keyword_id
		p = memchr(p, 0)
		p += 1
		goto keyword_str_loop
	:found_keyword_id
		return p + 1
	:no_such_keyword_id
		return .str_no_such_keyword_id
	:str_no_such_keyword_id
		string @BAD_KEYWORD_ID
		byte 0

; returns a unique number associated with the line `token` appears on.
function token_get_location
	argument token
	return *8token > 16 ; right shift by 16 to remove type,info, and extract 6 bytes of file,line

; turn pptokens into tokens, written to out.
; This corresponds to translation phases 5-6 and the first half of 7
; IMPORTANT: this function uses pointers to pptokens, so it should NOT be freed!
; Returns a pointer to the end of tokens.
function tokenize
	argument pptokens
	argument out
	; you might think we wouldn't need these arguments because the pptokens array starts with
	; a line directive. but we also use this function to tokenize the expression of a #if,
	; where that isn't the case.
	argument initial_filename
	argument initial_line_number
	local in
	local file
	local line_number
	local b
	local c
	local n
	local p
	local data
	local significand
	local exponent
	local new_exponent
	local pow10
	local integer
	local fraction
	local lower
	local upper
	
	file_add(initial_filename)
	file = file_get_index(initial_filename)
	line_number = initial_line_number
	
	
	in = pptokens
	:tokenize_loop
		c = *1in
		if c == '$ goto tokenize_line_directive
		if c == 32 goto tokenize_skip_pptoken
		if c == 10 goto tokenize_newline
		if c == '' goto tokenize_constant_char
		if c == '" goto tokenize_string_literal
		if c == 0 goto tokenize_loop_end
		
		b = get_keyword_id(in)
		if b != 0 goto tokenize_keyword
		
		b = isdigit_or_dot(c)
		if b != 0 goto tokenize_number
		
		; it's an identifier. we just need to make sure it's made up of identifier characters.
		p = in
		b = isalpha_or_underscore(*1p)
		if b == 0 goto bad_token
		
		:ident_check_loop
			b = isalnum_or_underscore(*1p)
			if b == 0 goto bad_token
			p += 1
			if *1p != 0 goto ident_check_loop
		; all good.
		*1out = TOKEN_IDENTIFIER
		out += 2 ; no info
		data = in ; data will point to the identifier name
		pptoken_skip(&in)
		goto token_output
		
		:tokenize_newline
			line_number += 1
			pptoken_skip(&in)
			goto tokenize_loop
		:tokenize_skip_pptoken
			pptoken_skip(&in)
			goto tokenize_loop
		:tokenize_line_directive
			in += 1
			line_number = stoi(in)
			in = memchr(in, 32)
			in += 1
			file_add(in)
			file = file_get_index(in)
			pptoken_skip(&in)
			goto tokenize_loop
		:token_no_data
			data = 0
			; (fallthrough)
		:token_output ; write token location & data (see local variable data), and continue tokenizing
			*2out = file
			out += 2
			*4out = line_number
			out += 4
			*8out = data
			out += 8
			goto tokenize_loop
		:tokenize_keyword
			pptoken_skip(&in)
			*1out = b ; type
			; no info for keywords
			out += 2
			goto token_no_data
		:tokenize_number
			; first, check if it's a float
			b = strchr(in, '.)
			if b != 0 goto tokenize_float
			b = strchr(in, 'x) ; e may appear in hex integer literals, so we need to check this
			if b != 0 goto tokenize_hex_integer
			b = strchr(in, 'X)
			if b != 0 goto tokenize_hex_integer
			b = strchr(in, 'e) ; exponent
			if b != 0 goto tokenize_float
			b = strchr(in, 'E) ; exponent
			if b != 0 goto tokenize_float
			if *1in == '0 goto tokenize_octal_integer ; fun fact: in the C89 standard, 0 is considered an octal integer
				; plain ol' decimal constant
				n = strtoi(&in, 10)
				goto tokenize_finish_integer
			:tokenize_hex_integer
				if *1in != '0 goto bad_number_token
				in += 1
				c = *1in
				c &= 223 ; 223 = ~32 -- remove case
				if c != 'X goto bad_number_token
				in += 1
				n = strtoi(&in, 16)
				goto tokenize_finish_integer
			:tokenize_octal_integer
				in += 1 ; skip 0
				n = strtoi(&in, 8)
				goto tokenize_finish_integer
			:tokenize_finish_integer
			c = read_number_suffix(file, line_number, &in)
			if c == NUMBER_SUFFIX_F goto f_suffix_on_integer
			in += 1 ; move past null separator
			*1out = TOKEN_CONSTANT_INT
			out += 1
			*1out = c ; info = suffix
			out += 1
			data = n
			goto token_output
		:tokenize_constant_char
			in += 1
			c = read_c_char(&in)
			if *1in != '' goto bad_char_constant
			if c ] 255 goto bad_char_constant
			pptoken_skip(&in)
			*1out = TOKEN_CONSTANT_CHAR
			out += 2 ; no info
			data = c
			goto token_output
		:tokenize_string_literal
			data = rodata_end_addr
			p = output_file_data + rodata_end_addr
			
			:string_literal_loop
				in += 1 ; skip opening "
				:string_literal_char_loop
					if *1in == '" goto string_literal_char_loop_end
					c = read_c_char(&in)
					if c ] 255 goto bad_char_in_string
					*1p = c
					p += 1
					goto string_literal_char_loop					
				:string_literal_char_loop_end
				pptoken_skip(&in) ; skip closing "
				pptoken_skip_whitespace(&in, &line_number)
				if *1in == '" goto string_literal_loop ; string concatenation, e.g. "Hello, " "world!"
			*1p = 0 ; null terminator
			p += 1
			rodata_end_addr = p - output_file_data
			
			*1out = TOKEN_STRING_LITERAL
			out += 2 ; no info
			goto token_output
		:tokenize_float
			; @NONSTANDARD: this doesn't allow for floats whose integral part is >=2^64, e.g. 1000000000000000000000000.0
			significand = 0
			exponent = 0
			pow10 = 0
			integer = strtoi(&in, 10)
			fraction = 0
			if *1in != '. goto float_no_fraction 
			in += 1
			p = in
			fraction = strtoi(&in, 10)
			; e.g. to turn 35 into .35, multiply by 10^-2
			pow10 = p - in
			;putnln_signed(pow10)
			if pow10 < -400 goto bad_float
			:float_no_fraction
			; construct the number integer + fraction*10^pow10
			; first, deal with the fractional part
			significand = fraction
			float_multiply_by_power_of_10(&significand, &exponent, pow10)
			
			if integer == 0 goto float_no_integer
			; now deal with the integer part
			new_exponent = leftmost_1bit(integer)
			new_exponent -= 58
			n = new_exponent - exponent
			significand = right_shift(significand, n)
			exponent = new_exponent
			significand += right_shift(integer, exponent)
			:float_no_integer
			
			if *1in == 'e goto float_exponent
			if *1in == 'E goto float_exponent
			
			:float_have_significand_and_exponent
			if significand == 0 goto float_zero
			normalize_float(&significand, &exponent)
			; make number round to the nearest representable float roughly (this is what gcc does)
			; this fails for 5e-100 probably because of imprecision, but mostly works
			significand += 15
			; reduce to 53-bit significand (top bit is removed to get 52)
			significand >= 5
			exponent += 5
			exponent += 52  ; 1001010111... => 1.001010111... 
			n = leftmost_1bit(significand)
			exponent += n - 52 ; in most cases, this is 0, but sometimes it turns out to be 1.
			b = 1 < n
			significand &= ~b
			data = significand
			
			if exponent <= -1023 goto float_zero ; this number is too small in magnitude to be represented as a double. it becomes 0
			if exponent >= 1024 goto float_infinity ; number too big to be represented as a double.
			exponent += 1023 ; float format
			
			data |= exponent < 52
			
			:float_have_data
			*1out = TOKEN_CONSTANT_FLOAT
			out += 1
			; suffix
			*1out = read_number_suffix(file, line_number, &in)
			pptoken_skip(&in)
			out += 1
			goto token_output
			:float_exponent
				in += 1
				if *1in == '+ goto float_exponent_plus
				if *1in == '- goto float_exponent_minus
				; e.g. 1e100
				pow10 = strtoi(&in, 10)
				:float_have_exponent
				float_multiply_by_power_of_10(&significand, &exponent, pow10)
				goto float_have_significand_and_exponent
			:float_exponent_plus
				; e.g. 1e+100
				in += 1
				pow10 = strtoi(&in, 10)
				goto float_have_exponent
			:float_exponent_minus
				; e.g. 1e-100
				in += 1
				pow10 = strtoi(&in, 10)
				pow10 = 0 - pow10
				goto float_have_exponent
			:float_zero
				data = 0
				goto float_have_data
			:float_infinity
				data = 0x7ff0000000000000 ; double infinity
				goto float_have_data
	:tokenize_loop_end
	; EOF token
	*1out = TOKEN_EOF
	out += 2
	*2out = file
	out += 2
	*4out = line_number
	out += 12
	
	return out
	:f_suffix_on_integer
		compile_error(file, line_number, .str_f_suffix_on_integer)
	:str_f_suffix_on_integer
		string Integer with f suffix.
		byte 0
	:bad_number_token
		compile_error(file, line_number, .str_bad_number_token)
	:str_bad_number_token
		string Bad number literal.
		byte 0
	:bad_char_constant
		compile_error(file, line_number, .str_bad_char_constant)
	:str_bad_char_constant
		string Bad character constant. Note that multibyte constants are not supported.
		byte 0
	:bad_char_in_string
		compile_error(file, line_number, .str_bad_char_in_string)
	:str_bad_char_in_string
		string Bad character in string literal.
		byte 0
	:bad_token
		compile_error(file, line_number, .str_bad_token)
	:str_bad_token
		string Bad token.
		byte 0
	:bad_float
		compile_error(file, line_number, .str_bad_float)
	:str_bad_float
		string Bad floating-point number.
		byte 0

function float_multiply_by_power_of_10
	argument p_significand
	argument p_exponent
	argument pow10
	local significand
	local exponent
	local p
	local lower
	local upper
	local n
	significand = *8p_significand
	exponent = *8p_exponent

	p = powers_of_10
	p += pow10 < 4
	full_multiply_signed(significand, *8p, &lower, &upper)
	if upper == 0 goto fmultiply2_no_upper
		n = leftmost_1bit(upper)
		n += 1
		significand = lower > n
		exponent += n
		n = 64 - n
		significand |= upper < n
		goto fmultiply2_cont
	:fmultiply2_no_upper
		significand = lower
		goto fmultiply2_cont
	:fmultiply2_cont
	p += 8
	exponent += *8p
	
	*8p_significand = significand
	*8p_exponent = exponent
	return 0
	
; return character or escaped character from *p_in, advancing accordingly
; returns -1 on bad character
function read_c_char
	argument p_in
	local in
	local c
	local x
	in = *8p_in
	if *1in == '\ goto escape_sequence
	; no escape sequence; just a normal character
	c = *1in
	in += 1
	goto escape_sequence_return
	
	:escape_sequence
		in += 1
		c = *1in
		in += 1
		if c == 'x goto escape_sequence_hex
		if c == '' goto escape_sequence_single_quote
		if c == '" goto escape_sequence_double_quote
		if c == '? goto escape_sequence_question
		if c == '\ goto escape_sequence_backslash
		if c == 'a goto escape_sequence_bell
		if c == 'b goto escape_sequence_backspace
		if c == 'f goto escape_sequence_form_feed
		if c == 'n goto escape_sequence_newline
		if c == 'r goto escape_sequence_carriage_return
		if c == 't goto escape_sequence_tab
		if c == 'v goto escape_sequence_vertical_tab
		; octal
		in -= 1
		x = isoctdigit(*1in)
		if x == 0 goto return_minus1
		c = *1in - '0
		in += 1
		x = isoctdigit(*1in)
		if x == 0 goto escape_sequence_return
		c <= 3
		c += *1in - '0
		in += 1
		x = isoctdigit(*1in)
		if x == 0 goto escape_sequence_return
		c <= 3
		c += *1in - '0
		in += 1
		if c ] 255 goto return_minus1 ; e.g. '\712'
		goto escape_sequence_return
	:escape_sequence_hex
		x = in
		c = strtoi(&in, 16)
		if in == x goto return_minus1 ; e.g. '\xhello'
		if c ] 255 goto return_minus1 ; e.g. '\xabc'
		goto escape_sequence_return
	:escape_sequence_single_quote
		c = ''
		goto escape_sequence_return
	:escape_sequence_double_quote
		c = '"
		goto escape_sequence_return
	:escape_sequence_question
		c = '?
		goto escape_sequence_return
	:escape_sequence_backslash
		c = '\
		goto escape_sequence_return
	:escape_sequence_bell
		c = 7
		goto escape_sequence_return
	:escape_sequence_backspace
		c = 8
		goto escape_sequence_return
	:escape_sequence_form_feed
		c = 12
		goto escape_sequence_return
	:escape_sequence_newline
		c = 10
		goto escape_sequence_return
	:escape_sequence_carriage_return
		c = 13
		goto escape_sequence_return
	:escape_sequence_tab
		c = 9
		goto escape_sequence_return
	:escape_sequence_vertical_tab
		c = 11
		goto escape_sequence_return
	:escape_sequence_return
	*8p_in = in
	return c


function read_number_suffix
	argument file
	argument line_number
	argument p_s
	local s
	local c
	local suffix
	s = *8p_s
	c = *1s
	suffix = 0
	if c == 0 goto number_suffix_return
	if c == 'u goto number_suffix_u
	if c == 'U goto number_suffix_u
	if c == 'l goto number_suffix_l
	if c == 'L goto number_suffix_l
	if c == 'f goto number_suffix_f
	if c == 'F goto number_suffix_f
	goto bad_number_suffix
	:number_suffix_u
		s += 1
		c = *1s
		if c == 'l goto number_suffix_ul
		if c == 'L goto number_suffix_ul
		if c != 0 goto bad_number_suffix
		suffix = NUMBER_SUFFIX_U
		goto number_suffix_return
	:number_suffix_l
		s += 1
		c = *1s
		if c == 'u goto number_suffix_ul
		if c == 'U goto number_suffix_ul
		if c == 'l goto number_suffix_l  ; handle ll suffix (even though it's C99)
		if c == 'L goto number_suffix_l
		if c != 0 goto bad_number_suffix
		suffix = NUMBER_SUFFIX_L
		goto number_suffix_return
	:number_suffix_ul
		s += 1
		c = *1s
		if c == 'l goto number_suffix_l  ; handle ll suffix (even though it's C99)
		if c == 'L goto number_suffix_l
		if c != 0 goto bad_number_suffix
		suffix = NUMBER_SUFFIX_UL
		goto number_suffix_return
	:number_suffix_f
		s += 1
		c = *1s
		if c != 0 goto bad_number_suffix
		suffix = NUMBER_SUFFIX_F
		goto number_suffix_return
	:number_suffix_return
	*8p_s = s
	return suffix
	
	:bad_number_suffix
		compile_error(file, line_number, .str_bad_number_suffix)
	:str_bad_number_suffix
		string Bad number suffix.
		byte 0
	
function print_tokens
	argument tokens
	argument tokens_end
	local p
	local s
	p = tokens
	:print_tokens_loop
		if p ]= tokens_end goto print_tokens_loop_end
		if *1p == 0 goto print_tokens_loop_end
		if *1p > 20 goto print_token_keyword 
		if *1p == TOKEN_CONSTANT_INT goto print_token_int
		if *1p == TOKEN_CONSTANT_CHAR goto print_token_char
		if *1p == TOKEN_CONSTANT_FLOAT goto print_token_float
		if *1p == TOKEN_STRING_LITERAL goto print_token_string_literal
		if *1p == TOKEN_IDENTIFIER goto print_token_identifier
		if *1p == TOKEN_EOF goto print_token_eof
		puts(.str_print_bad_token)
		exit(1)
		:print_token_keyword
			s = get_keyword_str(*1p)
			puts(s)
			goto print_token_data
		:print_token_int
			puts(.str_constant_int)
			goto print_token_info
		:print_token_char
			puts(.str_constant_char)
			goto print_token_data
		:print_token_string_literal
			puts(.str_string_literal)
			goto print_token_data
		:print_token_identifier
			s = p + 8
			puts(*8s)
			goto print_token_data
		:print_token_float
			p += 8
			puts(.str_constant_float)
			putx64(*8p)
			p += 8
			putc(32)
			goto print_tokens_loop
		:print_token_eof
			puts(.str_eof)
			goto print_token_data
		:print_token_info
		p += 1
		putc('~)
		putn(*1p)
		p -= 1
		:print_token_data
		p += 2
		putc('@)
		putn(*2p)
		p += 2
		putc(':)
		putn(*4p)
		p += 4
		putc(61)
		putn(*8p)
		p += 8
		putc(32)
		goto print_tokens_loop
	:print_tokens_loop_end
	putc(10)
	return
	:str_constant_int
		string integer
		byte 0
	:str_constant_float
		string float
		byte 0
	:str_constant_char
		string character
		byte 0
	:str_string_literal
		string string
		byte 0
	:str_print_bad_token
		string Unrecognized token type in print_tokens. Aborting.
		byte 10
		byte 0
	:str_eof
		string EOF
		byte 0

function print_token
	argument token
	local p
	p = token + 16
	print_tokens(token, p)
	return
