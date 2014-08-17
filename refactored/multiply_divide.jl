export *
export sign, monotonicity, intrinsic_vexity, evaluate, dual_conic_form

### Multiplication

type MultiplyAtom <: AbstractExpr
  head::Symbol
  id::Uint64
  children::(AbstractExpr, AbstractExpr)
  size::(Int64, Int64)

  function MultiplyAtom(x::AbstractExpr, y::AbstractExpr)
    if x.size == (1, 1)
      sz = y.size
    elseif y.size == (1, 1)
      sz = x.size
    elseif x.size[2] ==  y.size[1]
      sz = (x.size[1], y.size[2])
    else
      error("Cannot multiply two expressions of sizes $(x.size) and $(y.size)")
    end
    children = (x, y)
    return new(:*, hash(children), children, sz)
  end
end

function sign(x::MultiplyAtom)
  return sign(x.children[1]) * sign(x.children[2])
end

function monotonicity(x::MultiplyAtom)
  return (sign(x.children[2]) * Nondecreasing(), sign(x.children[1]) * Nondecreasing())
end

function intrinsic_vexity(x::MultiplyAtom)
  if x.children[1].head != :constant && x.children[2].head != :constant
    return NotDcp()
  else
    return ConstVexity()
  end
end

function evaluate(x::MultiplyAtom)
  return evaluate(x.children[1]) * evaluate(x.children[2])
end

function dual_conic_form(x::MultiplyAtom)
  # scalar multiplication
  if x.children[1].size == (1, 1) || x.children[2].size == (1, 1)
    if x.children[1].head == :constant
      const_child = x.children[1]
      expr_child = x.children[2]
    else
      const_child = x.children[2]
      expr_child = x.children[1]
    end
    objective, constraints = dual_conic_form(expr_child)
    objective = reshape([const_child.value], get_vectorized_size(const_child), 1) * objective

  # left matrix multiplication
  elseif x.children[1].head == :constant
    objective, constraints = dual_conic_form(x.children[2])
    objective = kron(speye(x.size[2]), x.children[1].value) * objective
  # right matrix multiplication
  else
    objective, constraints = dual_conic_form(x.children[2])
    objective = kron(x.children[2].value', speye(x.size[1])) * objective
  end
  return (objective, constraints)
end

*(x::AbstractExpr, y::AbstractExpr) = MultiplyAtom(x, y)
*(x::Value, y::AbstractExpr) = MultiplyAtom(Constant(x), y)
*(x::AbstractExpr, y::Value) = MultiplyAtom(x, Constant(y))
