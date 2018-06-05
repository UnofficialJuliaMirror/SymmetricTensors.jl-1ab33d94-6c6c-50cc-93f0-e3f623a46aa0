"""Type constructor

frame - stores ArrayNArrays{T,N}
bls - Int, size of ordinary block
bln - Int, number of blocks
datasize - Int, size of data stored (in each direction the same)
sqr - Bool, is the last block size a same as ordinary's block size
"""
immutable SymmetricTensornew{T <: AbstractFloat, N}
    frame::ArrayNArrays{T,N}
    bls::Int
    bln::Int
    dats::Int
    sqr::Bool
    function (::Type{SymmetricTensornew})(frame::ArrayNArrays{T,N};
        testdatstruct::Bool = true) where {T, N}
        # bls = size(frame[fill(1, N)...].value, 1)
        bls = size(frame[fill(1, N)...], 1)
        bln = size(frame, 1)
        # last_block = size(frame[end].value, 1)
        last_block = size(frame[end], 1)
        dats = bls * (bln - 1) + last_block
        if testdatstruct
          frtest(frame)
        end
        new{T, N}(frame, bls, bln, dats, bls == last_block)
    end
end

#obsolete

immutable SymmetricTensor{T <: AbstractFloat, N}
    frame::NullableArray{Array{T,N},N}
    bls::Int
    bln::Int
    dats::Int
    sqr::Bool
    function (::Type{SymmetricTensor})(frame::NullableArray{Array{T,N},N};
       testdatstruct::Bool = true) where {T, N}
        bls = size(frame[fill(1,N)...].value,1)
        bln = size(frame, 1)
        last_block = size(frame[end].value, 1)
        dats = bls * (bln-1) + last_block
        if testdatstruct
          frtest(frame)
        end
        new{T, N}(frame, bls, bln, dats, bls == last_block)
    end
end

"""
  unfold(ar::Array{N}, mode::Int)

Returns an matrix being an unfold of N dims array in given mode.

```jldoctest
julia> A = reshape(collect(1.:8.), 2, 2, 2);

julia> unfold(A, 1)
2×4 Array{Float64,2}:
 1.0  3.0  5.0  7.0
 2.0  4.0  6.0  8.0

 julia> unfold(A, 2)
 2×4 Array{Float64,2}:
  1.0  2.0  5.0  6.0
  3.0  4.0  7.0  8.0

  julia> unfold(A, 3)
  2×4 Array{Float64,2}:
   1.0  2.0  3.0  4.0
   5.0  6.0  7.0  8.0
```
"""
function unfold(ar::Array{T,N}, mode::Int) where {T <: Real, N}
    C = [1:mode-1; mode+1:N]
    i = size(ar)
    k = prod(i[C])
    return reshape(permutedims(ar,[mode; C]), i[mode], k)
end


"""
  issymetric(ar::Array{N}, atol::Float64)

Returns: Assertion Error if not symmetric given a tolerance.

```jldoctest
julia> A = reshape(collect(1.:8.), 2, 2, 2);

julia> julia> issymetric(A)
ERROR: AssertionError: not symmetric
```
"""
function issymetric(ar::Array{T, N}, atol::Float64 = 1e-7) where {T <: AbstractFloat, N}
  for i=2:N
     maximum(abs.(unfold(ar, 1)-unfold(ar, i))) < atol ||throw(AssertionError("not symmetric"))
  end
end

"""
  frtest(data::ArrayNArrays{T,N})

Returns assertion error if: all sizes of nullable array not equal, at least
  some undergiagonal block not null, some blocks (not last) not squared,
  some diagonal blocks not symmetric.
"""
function frtest(data::ArrayNArrays{T,N}) where {T <: AbstractFloat, N}
  bln = size(data, 1)
  bls = size(data[fill(1, N)...], 1)
  all(collect(size(data)) .== bln) || throw(AssertionError("frame not has non-equal dimensions"))

  for i in CartesianRange(size(data))
      if data[i]!=nothing && !issorted(i.I)
          throw(AssertionError("underdiagonal block not null"))
      end
  end

  for i in pyramidindices(N, bln-1)
    @inbounds all(collect(size(data[i...])) .== bls)||
        throw(AssertionError("$i block not square"))
  end
  for i=1:bln
    # @inbounds issymetric(data[fill(i, N)...].value)
    @inbounds issymetric(data[fill(i, N)...])
  end
end

#obsolete

function frtest(data::NullableArray{Array{T,N},N}) where {T <: AbstractFloat, N}
  bln = size(data, 1)
  bls = size(data[fill(1,N)...].value,1)
  all(collect(size(data)) .== bln) || throw(AssertionError("frame not square"))
  not_nulls = .!data.isnull
  !any(map(x->.!issorted(ind2sub(not_nulls, x)), find(not_nulls))) ||
  throw(AssertionError("underdiag. block not null"))
  for i in indices(N, bln-1)
    @inbounds all(collect(size(data[i...].value)) .== bls)||
    throw(AssertionError("$i block not square"))
  end
  for i=1:bln
    @inbounds issymetric(data[fill(i, N)...].value)
  end
end



"""
  pyramidindices(dims::Int, tensize::Int)

```jldoctest
julia> pyramidindices(2,3)
6-element Array{Tuple{Int64,Int64},1}:
 (1,1)
 (1,2)
 (1,3)
 (2,2)
 (2,3)
 (3,3)
```
"""
function pyramidindices(dims::Int, tensize::Int)
    multinds = Tuple{fill(Int,dims)...}[]
    @eval begin
        @nloops $dims i x -> (x==$dims)? (1:$tensize): (i_{x+1}:$tensize) begin
            @inbounds multind = @ntuple $dims x -> i_{$dims-x+1}
            push!($multinds, multind)
        end
    end
    multinds
end

# obsolete

indices(dims::Int, tensize::Int) = pyramidindices(dims, tensize)
"""

    sizetest(dats::Int, bls::Int)

Returns: DimensionMismatch if blocks size is grater than data size.

```jldoctest
julia> SymmetricTensors.sizetest(2,3)
ERROR: DimensionMismatch("bad block size 3 > 2")
```
"""
sizetest(dats::Int, bls::Int) =
  (dats >= bls > 0)|| throw(DimensionMismatch("bad block size $bls > $dats"))

"""
  getblockunsafe(st::SymmetricTensor, i::Tuple)

Returns a block from Symmetric Tensor, unsafe works only if multi-index is sorted
"""

getblockunsafe(st::SymmetricTensornew, mulind::Tuple) = st.frame[mulind...]

#obsolete

getblockunsafe(st::SymmetricTensor, mulind::Tuple) = st.frame[mulind...].value


"""
    getblock(st::SymmetricTensor, i::Tuple)

Returns a block from Symmetric Tensor, works for all multi-indices also not sorted
"""
function getblock(st::Union{SymmetricTensor, SymmetricTensornew}, mulind::Tuple)
  ind = sortperm([mulind...])
  permutedims(getblockunsafe(st, mulind[ind]), invperm(ind))
end

"""
    getindex(st::SymmetricTensor, i::Tuple)

Returns a Symmetric Tensor element for a given multi-index
"""

function getindex(st::Union{SymmetricTensor, SymmetricTensornew}, mulind::Int...)
  b = st.bls
  j = map(a -> div((a-1), b)+1, mulind)
  i = map(a -> ((a-1)%b)+1, mulind)
  getblock(st, j)[i...]
end

"""

    ind2range(i::Int, bls::Int, dats::Int)

Returns a range given index i, size of a block and size of data

```jldoctest
julia> ind2range(2,3,5)
4:5
```
"""
ind2range(i::Int, bls::Int, dats::Int) = (i-1)*bls+1: ((i*bls <= dats)? i*bls: dats)

"""
  convert(::Type{SymmetricTensor}, data::Array{N}, bls::Int)

Returns: data in SymmetricTensor form.
```jldoctest
julia> a = reshape(collect(1.:16.), 4, 4);

julia> convert(SymmetricTensor, a*a')
SymmetricTensors.SymmetricTensor{Float64,2}(Union{Array{Float64,2}, Void}[[276.0 304.0; 304.0 336.0][332.0 360.0; 368.0 400.0]; nothing [404.0 440.0; 440.0 480.0]], 2, 2, 4, true)
```
"""

function convert(::Type{SymmetricTensornew}, data::Array{T, N}, bls::Int = 2) where {T <: AbstractFloat, N}
  issymetric(data)
  dats = size(data,1)
  sizetest(dats, bls)
  bln = mod(dats,bls)==0 ?  dats÷bls : dats÷bls + 1
  symten = arraynarrays(T, fill(bln, N)...)
  # fill!(symten, nothing)
  for writeind in pyramidindices(N, bln)
      readind = map(k::Int -> ind2range(k, bls, dats), writeind)
      @inbounds symten[writeind...] = data[readind...]
  end
  SymmetricTensornew(symten)
end

#obsolete

function convert(::Type{SymmetricTensor}, data::Array{T, N}, bls::Int = 2) where {T <: AbstractFloat, N}
  issymetric(data)
  dats = size(data,1)
  sizetest(dats, bls)
  bln = mod(dats,bls)==0 ?  dats÷bls : dats÷bls + 1
  symten = NullableArray(Array{T, N}, fill(bln, N)...)
  for writeind in indices(N, bln)
      readind = map(k::Int -> ind2range(k, bls, dats), writeind)
      @inbounds symten[writeind...] = data[readind...]
  end
  SymmetricTensor(symten)
end

"""
  convert(::Type{Array}, st::SymmetricTensor{N})

Return N dims array converted from SymmetricTensor type

"""
function convert(::Type{Array}, st::Union{SymmetricTensor{T,N}, SymmetricTensornew{T,N}}) where {T<:AbstractFloat, N}
  array = zeros(T, fill(st.dats, N)...)
  for i = 1:(st.bln^N)
    readind = ind2sub((fill(st.bln, N)...), i)
    writeind = map(k -> ind2range(readind[k], st.bls, st.dats), 1:N)
    @inbounds array[writeind...] = getblock(st, readind)
  end
  array
end

# ---- basic operations on Symmetric Tensors ----

"""
  diag(st::SymmetricTensor{N})

Return vector of floats, the super-diag of st

"""

diag(st::Union{SymmetricTensor{T,N}, SymmetricTensornew{T,N}}) where {T<: AbstractFloat, N} = map(i->st[fill(i, N)...], 1:st.dats)


"""
  broadcast(f::Function, st::SymmetricTensor{N}, num)

Returns data in SymmetricTensor type after elementwise operation (f) of
 Symmetric Tensor and number
"""
function broadcast(f::Function, st::SymmetricTensornew{T,N}, num::Real) where {T<: AbstractFloat, N}
  stret = similar(st.frame)
  for i in pyramidindices(N, st.bln)
    @inbounds stret[i...] = f(getblockunsafe(st, i), num)
  end
  SymmetricTensornew(stret; testdatstruct = false)
end


# obsolete

function broadcast(f::Function, st::SymmetricTensor{T,N}, num::Real) where {T<: AbstractFloat, N}
  stret = similar(st.frame)
  for i in pyramidindices(N, st.bln)
    @inbounds stret[i...] = f(getblockunsafe(st, i), num)
  end
  SymmetricTensor(stret; testdatstruct = false)
end


broadcast(f::Function, num::Real, st::Union{SymmetricTensor{T,N}, SymmetricTensornew{T,N}}) where {T<: AbstractFloat, N} = broadcast(f, st, num)

"""
  broadcast(f::Function, st::SymmetricTensor{T,N}...)

Returns the elementwise operation, the overload of
crodcast function from Base
"""
function broadcast(f::Function, st:: SymmetricTensornew{T,N}...) where {T<: AbstractFloat, N}
  narg = size(st, 1)
  stret = similar(st[1].frame)
  for i in pyramidindices(N, st[1].bln)
    @inbounds stret[i...] = broadcast(f, map(k -> getblockunsafe(st[k], i), 1:narg)...)
  end
  SymmetricTensornew(stret; testdatstruct = false)
end

#obsolete

function broadcast(f::Function, st::SymmetricTensor{T,N}...) where {T<: AbstractFloat, N}
  narg = size(st, 1)
  stret = similar(st[1].frame)
  for i in pyramidindices(N, st[1].bln)
    @inbounds stret[i...] = broadcast(f, map(k -> getblockunsafe(st[k], i), 1:narg)...)
  end
  SymmetricTensor(stret; testdatstruct = false)
end

# implements simple operations on bs structure

for f = (:+, :-)
  @eval function ($f)(st::Union{SymmetricTensor{T,N}, SymmetricTensornew{T,N}}...) where {T <: AbstractFloat, N}
    dats = st[1].dats
    for s in st
      if s.dats != dats
        throw(DimensionMismatch("dimensions must match"))
      end
    end
    broadcast($f, st...)
  end
end


for f = (:+, :-, :*, :/)
  @eval ($f)(st::Union{SymmetricTensor{T}, SymmetricTensornew{T}}, numb::S) where {T <: AbstractFloat, S <: Real} =
  broadcast($f, st, numb)
end

for f = (:+, :*)
  @eval ($f)(numb::S, st::Union{SymmetricTensor{T}, SymmetricTensornew{T}}) where {T <: AbstractFloat, S <: Real} =
  broadcast($f, numb, st)
end
