# frozen_string_literal: true

raw_private_key = '<<rsa_key_with/n_goes_here>>'

File.open('./rsa_private_key.pem', 'w').write(raw_private_key)
