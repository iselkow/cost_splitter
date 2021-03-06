require 'sinatra'
require 'data_mapper'

DataMapper::Logger.new($stdout, :debug)
DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/cost_splitter.db")

class Person
  include DataMapper::Resource

  property :id, Serial
  property :name, String
  property :paid, Boolean, default: false

  has n, :person_expense_records
  has n, :expenses, through: :person_expense_records

  def balance
    BalanceCalculator.call[id]
  end

  def to_s
    name
  end

  def delete(expense_params)
    # reassign expenses
    expense_params.each do |k,v|
      expense_id = k.split('_')[1]
      expense = Expense.get(expense_id)

      if v == 'delete'
        expense.person_expense_records.destroy!
        expense.destroy!
      else
        expense.update!(person_id: v)
      end
    end

    # destroy person_expense_records
    person_expense_records.destroy!

    # destroy person
    destroy!
  end

  def expense_list
    expenses.map {|x| x.item}.join(", ")
  end

  def row_color
    if paid
      "success"
    elsif balance < 0
      "danger"
    end
  end
end

class Expense
  include DataMapper::Resource

  property :id, Serial
  property :cost, Decimal, precision: 8, scale: 2
  property :item, String

  has n, :person_expense_records
  has n, :people, through: :person_expense_records
  belongs_to :person

  def purchaser
    Person.first(id: person_id).name
  end

  def user_list
    people.map {|x| x.name }.join(", ")
  end

  def person_id_array
    people.map { |x| x.id }
  end

  def delete
    # destroy person_expense_records
    person_expense_records.destroy!

    # destroy expense
    destroy!
  end
end

class PersonExpenseRecord
  include DataMapper::Resource

  property :id, Serial

  belongs_to :expense
  belongs_to :person
end

class BalanceCalculator
  def self.call
    balances = {}

    # Set default balance to 0
    Person.each { |person| balances[person.id] = 0 }

    # Iterate over each expense
    Expense.each do |expense|

      # Increase the balance by the total cost for the purchaser
      purchaser_id = expense.person_id
      balances[purchaser_id] += expense.cost

      # Collect the number of users
      payer_list = expense.people.map { |person| person.id }
      payer_count = payer_list.length

      # Calculate share per user
      share_per_user = expense.cost / payer_count

      # Update balance for each user
      payer_list.each { |payer_id| balances[payer_id] -= share_per_user }
    end

    balances
  end
end

helpers do
  def strip_currency(str)
    str.gsub(/[^0-9|.]/, '')
  end

  def display_as_currency(decimal)
    "$" + sprintf("%.2f", decimal)
  end
end

DataMapper.finalize.auto_upgrade!

get '/' do
  redirect '/people'
end

get '/people' do
  @people = Person.all
  haml :people
end

post '/people' do
  Person.create(name: params[:name])
  redirect '/people'
end

get '/people/:id/edit' do
  @person = Person.get(params[:id])
  haml :edit_person
end

post '/people/:id/edit' do
  @person = Person.get(params[:id])
  @person.update(name: params[:name])

  redirect '/people'
end

get '/people/:id/delete' do
  person_id = params[:id]
  @person = Person.get(person_id)
  @person_expenses = Expense.all(person_id: person_id)
  other_people = Person.all.delete_if { |p| p == @person }
  @other_people_array = other_people.map { |p| [p.id, p.name] }
  @other_people_array.push(["delete", "Delete Expense"])

  haml :delete_person
end

post '/people/:id/delete' do
  if params.has_key?("ok")
    person = Person.get(params[:id])
    expense_params = params.select { |k,v| k =~ /expense_\d*/ }
    person.delete(expense_params)
  end

  redirect '/people'
end

post '/people/:id/mark_as_paid' do
  person = Person.get(params[:id])
  person.update(paid: true)

  redirect '/people'
end

get '/expenses' do
  @expenses = Expense.all
  @people = Person.all

  haml :expenses
end

post '/expenses' do
  expense = Expense.create(cost: strip_currency(params[:cost]), item: params[:item], person_id: params[:person_id])

  params[:person_expense_record].each do |person_id|
    PersonExpenseRecord.create(person_id: person_id, expense_id: expense.id)
  end

  redirect '/expenses'
end

get '/expenses/:id/edit' do
  @expense = Expense.get(params[:id])
  @people = Person.all
  @people_sharing_expense = @expense.person_id_array

  haml :edit_expense
end

post '/expenses/:id/edit' do
  @expense = Expense.get(params[:id])
  @expense.update(cost: strip_currency(params[:cost]), item: params[:item], person_id: params[:person_id])

  @expense.person_expense_records.destroy!

  params[:person_expense_record].each do |person_id|
    PersonExpenseRecord.create(person_id: person_id, expense_id: @expense.id)
  end

  redirect '/expenses'
end

get '/expenses/:id/delete' do
  expense_id = params[:id]
  @expense = Expense.get(expense_id)

  haml :delete_expense
end

post '/expenses/:id/delete' do
  if params.has_key?("ok")
    expense = Expense.get(params[:id])
    expense.delete
  end

  redirect '/expenses'
end
