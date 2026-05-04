from flask import Flask, render_template, request, redirect
from flask_sqlalchemy import SQLAlchemy
import os

app = Flask(__name__)

# Caminho onde o banco será criado. Na pasta 'data' para o Docker sobreviver.
db_path = os.path.join(os.path.dirname(__file__), 'data', 'acervo.db')
os.makedirs(os.path.dirname(db_path), exist_ok=True)
app.config['SQLALCHEMY_DATABASE_URI'] = f'sqlite:///{db_path}'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

# Nossa tabela de itens
class Item(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    nome = db.Column(db.String(200), nullable=False)
    tipo = db.Column(db.String(50))   # livro, cd, dvd...

@app.route('/')
def home():
    itens = Item.query.all()
    return render_template('index.html', itens=itens)

@app.route('/adicionar', methods=['POST'])
def adicionar():
    nome = request.form['nome']
    tipo = request.form['tipo']
    novo = Item(nome=nome, tipo=tipo)
    db.session.add(novo)
    db.session.commit()
    return redirect('/')

if __name__ == '__main__':
    with app.app_context():
        db.create_all()   # Cria o arquivo e tabela se não existir
    app.run(host='0.0.0.0', port=5000, debug=True)