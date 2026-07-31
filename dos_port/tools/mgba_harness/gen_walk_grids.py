#!/usr/bin/env python3
"""BFS a walkable path: Route 1 entry -> Viridian Pokecenter door -> the PC.

Gen 1 walkability: a map square (x,y) is enterable iff the BOTTOM-LEFT 8x8 tile
of its 16x16 block is in the tileset's coll_tiles list. Ledge tiles are not in
the list, so ledges read as walls (correct for a northbound walk).
"""
import collections, sys, re

ROOT = "/mnt/sdb1/Code/Active Code/pokeyellow_msdos"

def load_blockset(path):
    data = open(path, "rb").read()
    return [data[i:i+16] for i in range(0, len(data), 16)]

def load_map(blk_path, wblocks, hblocks, bst):
    blocks = open(blk_path, "rb").read()
    assert len(blocks) == wblocks*hblocks, (blk_path, len(blocks))
    # tile grid: 4 tiles per block each way
    W, H = wblocks*4, hblocks*4
    tiles = [[0]*W for _ in range(H)]
    for by in range(hblocks):
        for bx in range(wblocks):
            b = bst[blocks[by*wblocks+bx]]
            for ty in range(4):
                for tx in range(4):
                    tiles[by*4+ty][bx*4+tx] = b[ty*4+tx]
    return tiles  # [tile_row][tile_col]

def passable_grid(tiles, coll):
    H, W = len(tiles)//2, len(tiles[0])//2
    g = [[False]*W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            # bottom-left tile of the 2x2-tile square
            g[y][x] = tiles[2*y+1][2*x] in coll
    return g

def bfs(grid, start, goals, blocked=()):
    H, W = len(grid), len(grid[0])
    blocked = set(blocked)
    prev = {start: None}
    q = collections.deque([start])
    while q:
        cur = q.popleft()
        if cur in goals:
            path = []
            while cur:
                path.append(cur); cur = prev[cur]
            return path[::-1]
        x, y = cur
        for dx, dy in ((0,-1),(0,1),(-1,0),(1,0)):
            nx, ny = x+dx, y+dy
            if 0 <= nx < W and 0 <= ny < H and grid[ny][nx] and (nx,ny) not in prev and (nx,ny) not in blocked:
                prev[(nx,ny)] = (x,y); q.append((nx,ny))
    return None

def runs(path):
    out = []
    for (x0,y0),(x1,y1) in zip(path, path[1:]):
        d = {(0,-1):"UP",(0,1):"DOWN",(-1,0):"LEFT",(1,0):"RIGHT"}[(x1-x0,y1-y0)]
        if out and out[-1][0] == d: out[-1][1] += 1
        else: out.append([d,1])
    return out

OVERWORLD_COLL = {0x00,0x10,0x1b,0x20,0x21,0x23,0x2c,0x2d,0x2e,0x30,0x31,0x33,
                  0x39,0x3c,0x3e,0x52,0x54,0x58,0x5b}
POKECENTER_COLL = {0x11,0x1a,0x1c,0x3c,0x5e}

ow = load_blockset(f"{ROOT}/gfx/blocksets/overworld.bst")
pc = load_blockset(f"{ROOT}/gfx/blocksets/pokecenter.bst")

r1 = passable_grid(load_map(f"{ROOT}/maps/Route1.blk", 10, 18, ow), OVERWORLD_COLL)
vc = passable_grid(load_map(f"{ROOT}/maps/ViridianCity.blk", 20, 18, ow), OVERWORLD_COLL)
vp = passable_grid(load_map(f"{ROOT}/maps/ViridianPokecenter.blk", 7, 4, pc), POKECENTER_COLL)

# Route 1: enter from Pallet at (x=10, y=35). Goal: any x on row 0 that is
# passable AND whose Viridian counterpart (x+10, 35) is passable.
r1_goals = {(x,0) for x in range(20) if r1[0][x] and vc[35][x+10]}
p1 = bfs(r1, (10,35), r1_goals)
print("Route1 entry (10,35) ->", p1[-1], "steps:", runs(p1))

# Viridian: enter at (p1_end.x+10, 35); goal = Pokecenter door square (23,25).
vx = p1[-1][0] + 10
# NPC home squares as soft obstacles: avoid pathing THROUGH them (they wander,
# but avoiding homes reduces stall odds).
vc_npcs = [(13,20),(30,8),(30,25),(17,9),(18,9),(6,23),(17,5)]
p2 = bfs(vc, (vx,35), {(23,25)}, blocked=vc_npcs)
print("Viridian entry", (vx,35), "-> door (23,25) steps:", runs(p2))

# Pokecenter: warp drops the player at warp 1 = (x=3, y=7). Goal: (13,3),
# then face UP at the PC. Avoid NPC homes (gentleman x=10 wanders y).
p3 = bfs(vp, (3,7), {(13,3)}, blocked=[(4,3),(4,1),(3,1),(11,2)])
print("Pokecenter (3,7) -> PC spot (13,3) steps:", runs(p3))
