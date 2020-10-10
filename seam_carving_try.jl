### A Pluto.jl notebook ###
# v0.11.14

using Markdown
using InteractiveUtils

# ╔═╡ 54bf5dc0-062b-11eb-363b-87e0c5bb3d65
using Images

# ╔═╡ d9f9b342-062c-11eb-0e5b-117afa8de138
begin
	import Pkg
	Pkg.add(["Images", "ImageMagick", "PlutoUI", "ImageFiltering", "ImageView"])
	using ImageFiltering
	using Statistics
	using LinearAlgebra
end

# ╔═╡ 1c8cb640-0631-11eb-3c91-d950a4433c27
begin
	Pkg.add("ImageView")
	using ImageView
end

# ╔═╡ 81986260-062b-11eb-347c-1fed95ce551b
clock = load("clocknew.jpg")

# ╔═╡ abc4bd90-062b-11eb-01eb-613a4045e64a
size(clock)

# ╔═╡ ce334900-062b-11eb-274e-f15948f61336
Kernel.sobel()[2]

# ╔═╡ 33995b10-062f-11eb-0fcf-b7399267c147
function brightness(c)
	return 0.3 * c.r + 0.59 * c.g + 0.11 * c.b
end

# ╔═╡ 6d5ce980-062e-11eb-0d4e-6dd995a355b0
brightness.(clock)

# ╔═╡ 61c608d0-062f-11eb-2c25-d53abbd03ada


# ╔═╡ 30f46f40-062e-11eb-0b78-e7d67b940914
function find_energy(img)
	energy_x = imfilter(brightness.(img), Kernel.sobel()[2])
	energy_y = imfilter(brightness.(img), Kernel.sobel()[1])
	return sqrt.(energy_x.^2 + energy_y.^2)
end		

# ╔═╡ f3912f60-062f-11eb-0206-c73eab7ba736
energy_output = find_energy(clock)

# ╔═╡ 857bc920-0983-11eb-2447-47732a786e89
typeof(energy_output)

# ╔═╡ c88c52d0-0982-11eb-1354-e9a6caf8c18d
save("edgy.png", colorview(Gray, energy_output))

# ╔═╡ e7028480-071d-11eb-2c14-17d5c482da3e
imshow(energy_output)

# ╔═╡ 378d9110-071e-11eb-2804-fd86bb26eb84
imshow(energy_x)

# ╔═╡ 5aecbe10-071e-11eb-1c0c-ddf24c9da39b
imshow(energy_y)

# ╔═╡ 98cf0710-071e-11eb-3415-0f7284faeaf8
imshow(energy_x_y)

# ╔═╡ a6446870-0630-11eb-13ff-31881a87ca38
typeof(energy_output)

# ╔═╡ 9b0a9b00-0725-11eb-35e3-6bd3aff5fd19
# Generate energy map

# ╔═╡ ddf61b10-0725-11eb-12ca-678f272da8bb
size(energy_output)

# ╔═╡ a4583280-0725-11eb-2c55-d9796b0f49fb
function find_energy_map(energy)
	energy_map = zeros(size(energy))
	next_elements = zeros(Int, size(energy_map))
	
	energy_map[end,:] = energy[end,:]
	for i = size(energy)[1]-1:-1:1, j = 1:size(energy)[2]
		left = max(j-1, 1)
		right = min(size(energy)[2], j+1)
		local_energy, next_element = findmin(energy_map[i+1, left:right])
		energy_map[i,j] += energy[i,j] + local_energy
		next_elements[i,j] = next_element - 2
		if left == 1
			next_elements[i,j] += 1
		end
	end		
	return energy_map, next_elements
end

# ╔═╡ cbc23c90-0729-11eb-1e44-57ccc88ee7de
energy_map, next_elements = find_energy_map(energy_output)

# ╔═╡ ecee0ed0-0729-11eb-2f15-77c1780b7b26
imshow(energy_map)

# ╔═╡ fc88dcd0-072e-11eb-1471-0d52ef0fc943
function find_seam_at(element, next_elements)
	seam = zeros(Int, size(next_elements)[1])
	seam[1] = element
	
	for i = 2:length(seam)
		seam[i] = seam[i-1] + next_elements[i, seam[i-1]]
	end
	return seam
end

# ╔═╡ dfa6f3d0-072f-11eb-20e8-5b3eca9ea09f
find_seam_at(100, next_elements)

# ╔═╡ fcb8d100-072f-11eb-1ec9-65b751699afe
function find_seam(energy)
	energy_map, next_elements = find_energy_map(energy)
	_, min_element = findmin(energy_map[1,:])
	minimal_seam = find_seam_at(min_element, next_elements) 
	return minimal_seam
end

# ╔═╡ ecd31310-07f5-11eb-16a2-9bbcf0abd001
img1 = Array{RGB}(undef, (5,5))

# ╔═╡ 430d33a0-07f6-11eb-05e5-c5283e612e9c


# ╔═╡ 4f08b8a0-07ec-11eb-0cbc-09295966cc10
function remove_seam(img, seam)
	img_res = (size(img)[1], size(img)[2]-1)
	new_img = Array{RGB}(undef, img_res)
	
	for i = 1:length(seam)
		if seam[i] > 1 && seam[i] < size(img)[2]
			new_img[i, :] .= vcat(img[i, 1:seam[i]-1], img[i, seam[i]+1:end])
		elseif seam[i] == 1
			new_img[i, :] .= img[i, 2:end]
		elseif seam[i] == size(img)[2]
			new_img[i, :] .= img[i, 1:end-1]
		end
	end
	return new_img
end

# ╔═╡ e78bc4c2-07f9-11eb-0fc6-dfb7ee418523
function seam_carving(img, res)
	if res <= 0 || res > size(img)[2]
		error("resolution not acceptable")
	end
	
	for i = 1:(size(img)[2] - res)
		energy = find_energy(img)
		seam = find_seam(energy)
		img = remove_seam(img, seam)
	end
	return img
end

# ╔═╡ f4922910-07fa-11eb-0f33-ef4db66e7b0a
img2 = seam_carving(clock, 400)

# ╔═╡ d5199a30-07fc-11eb-1c42-0343ba6f8cfd
size(img2)

# ╔═╡ Cell order:
# ╠═54bf5dc0-062b-11eb-363b-87e0c5bb3d65
# ╠═81986260-062b-11eb-347c-1fed95ce551b
# ╠═abc4bd90-062b-11eb-01eb-613a4045e64a
# ╠═d9f9b342-062c-11eb-0e5b-117afa8de138
# ╠═ce334900-062b-11eb-274e-f15948f61336
# ╠═6d5ce980-062e-11eb-0d4e-6dd995a355b0
# ╠═33995b10-062f-11eb-0fcf-b7399267c147
# ╠═61c608d0-062f-11eb-2c25-d53abbd03ada
# ╠═30f46f40-062e-11eb-0b78-e7d67b940914
# ╠═f3912f60-062f-11eb-0206-c73eab7ba736
# ╠═857bc920-0983-11eb-2447-47732a786e89
# ╠═c88c52d0-0982-11eb-1354-e9a6caf8c18d
# ╠═1c8cb640-0631-11eb-3c91-d950a4433c27
# ╠═e7028480-071d-11eb-2c14-17d5c482da3e
# ╠═378d9110-071e-11eb-2804-fd86bb26eb84
# ╠═5aecbe10-071e-11eb-1c0c-ddf24c9da39b
# ╠═98cf0710-071e-11eb-3415-0f7284faeaf8
# ╠═a6446870-0630-11eb-13ff-31881a87ca38
# ╠═9b0a9b00-0725-11eb-35e3-6bd3aff5fd19
# ╠═ddf61b10-0725-11eb-12ca-678f272da8bb
# ╠═a4583280-0725-11eb-2c55-d9796b0f49fb
# ╠═cbc23c90-0729-11eb-1e44-57ccc88ee7de
# ╠═ecee0ed0-0729-11eb-2f15-77c1780b7b26
# ╠═fc88dcd0-072e-11eb-1471-0d52ef0fc943
# ╠═dfa6f3d0-072f-11eb-20e8-5b3eca9ea09f
# ╠═fcb8d100-072f-11eb-1ec9-65b751699afe
# ╠═ecd31310-07f5-11eb-16a2-9bbcf0abd001
# ╠═430d33a0-07f6-11eb-05e5-c5283e612e9c
# ╠═4f08b8a0-07ec-11eb-0cbc-09295966cc10
# ╠═e78bc4c2-07f9-11eb-0fc6-dfb7ee418523
# ╠═f4922910-07fa-11eb-0f33-ef4db66e7b0a
# ╠═d5199a30-07fc-11eb-1c42-0343ba6f8cfd
