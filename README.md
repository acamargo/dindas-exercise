# Dinda Dev Challenge

  This ruby app is a programming exercise build for Dinda's recruitment process.

# How to run it

  * Install RVM

    Follow the instructions on https://rvm.io/rvm/install

  * Install Ruby 2.3.0

    ```
    $ rvm install 2.3.0
    ```

  * Install Bundler gem

    ```
    $ gem install bundler
    ```

  * Install Git

    Follow the instructions on https://git-scm.com/book/en/v2/Getting-Started-Installing-Git

  * Clone this git repository

    ```
    $ git clone https://github.com/acamargo/dindas-exercise.git
    ```

  * Install the gems required by the application

    ```
    $ cd dindas_exercise
    $ bundle install
    ```

  * Run the tests and seed some fixture data for you

    ```
    $ ruby dindas_exercise.rb
    ```

  * Tweak the fixture data CSV files to meet your needs

    * contas.csv structure is an account by line where: `<account id>,<balance as integer value in cents>`

    * transacoes.csv structure is a book entry by line where: `<account id>,<book value as integer in cents>`

  * Run the app with your data

  ```
  $ ruby dindas_exercise.rb contas.csv transacoes.csv
  ```
