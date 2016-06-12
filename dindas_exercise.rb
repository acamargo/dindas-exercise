# encoding: utf-8
#
# Dinda's Exercise Ruby App
#
# Written by André Camargo
# June 2016

CHART_OF_ACCOUNTS_CSV = <<CSV
3,345
2,234
1,123
4,0
CSV

CASH_BOOK_CSV = <<CSV
1,100
2,66
1,-500
3,55
1,-100
1,1377
4,-1
CSV

require 'minitest'
require 'csv'

class ChartOfAccounts
  attr_reader :accounts, :fees

  def initialize
    @accounts = {}
    @fees = []
  end

  def add_account(account_id, account_balance)
    account_id_to_i = account_id.to_i
    @accounts[account_id_to_i] = Account.new(account_id_to_i, account_balance)
  end

  def add_fee(condition, action)
    @fees << [condition, action]
  end

  def add_default_fee!
    fee_condition = Proc.new {|book_entry| book_entry.withdraw? }
    fee_action = Proc.new do |cash_book, book_entry|
      cash_book.add_book_entry book_entry.account.id, -500, is_fee: true
    end
    add_fee fee_condition, fee_action
  end

  def to_csv
    @accounts.
      values.
      collect {|account| "#{account.id},#{account.balance_in_cents}" }.
      sort.
      join("\n")
  end

  def self.import_balance_from_csv(text)
    chart_of_accounts = new
    CSV.parse(text, headers: false).each do |row|
      account_id, account_balance = row
      chart_of_accounts.add_account(account_id, account_balance)
    end
    chart_of_accounts
  end

  def self.import_balance_from_csv_file(path)
    import_balance_from_csv File.read(path)
  end
end

class Account
  attr_accessor :id
  attr_reader :balance_in_cents

  def initialize(account_id, account_balance)
    @id = account_id.to_i
    @balance_in_cents = account_balance.to_i
  end

  def update_balance(value)
    @balance_in_cents += value.to_i
  end
end

class BookEntry
  attr_accessor :account, :value

  def initialize(account, value)
    @account = account
    @value = value.to_i
    @account.update_balance(@value)
  end

  def withdraw?
    @value < 0
  end

  def to_csv
    "#{@account.id},#{@value}"
  end
end

class CashBook
  def initialize(chart_of_accounts)
    @book_entries = []
    @chart_of_accounts = chart_of_accounts
  end

  def add_book_entry(account_id, value, options={})
    options[:is_fee] = false unless options.has_key? :is_fee
    account_id_to_i = account_id.to_i
    if account = @chart_of_accounts.accounts[account_id_to_i]
      book_entry = BookEntry.new(account, value)
      @book_entries << book_entry
      @chart_of_accounts.fees.each do |fee|
        condition, action = fee
        action.call(self, book_entry) if condition.call(book_entry)
      end unless options[:is_fee]
    end
  end

  def to_csv
    @book_entries.collect(&:to_csv).join("\n")
  end

  def self.import_book_entries_from_csv(chart_of_accounts, text)
    cash_book = new(chart_of_accounts)
    CSV.parse(text, headers: false).each do |row|
      account_id, value = row
      cash_book.add_book_entry(account_id, value)
    end
    cash_book
  end

  def self.import_book_entries_from_csv_file(chart_of_accounts, path)
    self.import_book_entries_from_csv chart_of_accounts, path
  end
end

class Tax
  attr_accessor :condition, :action
end

class Cli
  def self.process(args)
    balance_filename_csv, cash_book_filename_csv = args

    return false unless balance_filename_csv &&
      File.exists?(balance_filename_csv) &&
      cash_book_filename_csv &&
      File.exists?(cash_book_filename_csv)

    @chart_of_accounts = ChartOfAccounts.import_balance_from_csv_file(balance_filename_csv)
    @chart_of_accounts.add_default_fee!

    @cash_book = CashBook.import_book_entries_from_csv_file(@chart_of_accounts, cash_book_filename_csv)
    puts "Here it is what you're waiting for:"
    puts
    puts @chart_of_accounts.to_csv
  end

  def self.help
    puts "You didn't inform the balance and book entries CSV files."
    there_is_contas_csv = File.exists?('contas.csv')
    there_is_transacoes_csv = File.exists?('transacoes.csv')
    if there_is_contas_csv || there_is_transacoes_csv
      puts
      puts "Try it now:"
    else
      puts
      puts "So, I'm seeding some fixture data for you ;-)"
      unless there_is_contas_csv
        File.open('contas.csv', 'w+') do |file|
          file.write(CHART_OF_ACCOUNTS_CSV)
        end
        puts "File contas.csv created"
      end
      unless there_is_transacoes_csv
        File.open('transacoes.csv', 'w+') do |file|
          file.write(CASH_BOOK_CSV)
        end
        puts "File transacoes.csv created"
      end
    puts
    puts "Great! Now you can use the app running:"
    end
    puts
    puts "$ ruby dindas_exercise.rb contas.csv transacoes.csv"
  end

  def self.run(args)
    help unless process(args)
  end
end

# Tests --------------------------------------------------------------------

class ChartOfAccountsTest < MiniTest::Test
  def test_add_account
    chart_of_accounts = ChartOfAccounts.new
    chart_of_accounts.add_account 1, 123
    assert_equal "1,123", chart_of_accounts.to_csv
    chart_of_accounts.add_account 2, 234
    assert_equal "1,123\n2,234", chart_of_accounts.to_csv
  end

  def test_add_fee
    chart_of_accounts = ChartOfAccounts.new
    chart_of_accounts.add_default_fee!
    chart_of_accounts.add_account 1, 0
    
    cash_book = CashBook.new(chart_of_accounts)
    cash_book.add_book_entry 1, -100
    assert_equal "1,-600", chart_of_accounts.to_csv
  end
end

class AccountTest < MiniTest::Test
  def test_initialization
    account = Account.new('1', '123')
    assert_equal 1, account.id
    assert_equal 123, account.balance_in_cents
  end
end

class CashBookTest < MiniTest::Test
  def test_add_book_entry
    chart_of_accounts = ChartOfAccounts.new
    chart_of_accounts.add_account 1, 123
    chart_of_accounts.add_account 2, 0
    cash_book = CashBook.new(chart_of_accounts)
    cash_book.add_book_entry 1, 77
    assert_equal "1,77", cash_book.to_csv
    assert_equal "1,200\n2,0", chart_of_accounts.to_csv
    cash_book.add_book_entry 2, 77
    assert_equal "1,77\n2,77", cash_book.to_csv
    assert_equal "1,200\n2,77", chart_of_accounts.to_csv
  end

  def test_fixture_data_csv
    chart_of_accounts = ChartOfAccounts.import_balance_from_csv(CHART_OF_ACCOUNTS_CSV)
    chart_of_accounts.add_default_fee!
    cash_book = CashBook.import_book_entries_from_csv(chart_of_accounts, CASH_BOOK_CSV)
    assert_equal "1,0\n2,300\n3,400\n4,-501", chart_of_accounts.to_csv
  end
end

# Script -------------------------------------------------------------------

if Minitest.run
  puts
  puts "Yay! All tests passed!"
  puts '-' * 80
  puts
  Cli.run(ARGV)
else
  puts
  puts "Tests failed! Aborting execution!"
  puts
end
puts
