test-admin:
	@echo "Testing admin"
	ape test tests/test_admin.py -s

test-fees:
	@echo "Testing fees"
	ape test tests/test_fees.py -s

test-gas:
	@echo "Testing gas"
	ape test tests/test_gas.py -s

test-spray:
	@echo "Testing spray"
	ape test tests/test_spray.py -s

test-swap:
	@echo "Testing swap"
	ape test tests/test_swap.py -s

test-transfer:
	@echo "Testing transfer"
	ape test tests/test_transfer.py -s

test: 
	@echo "Testing all"
	ape test -I -s