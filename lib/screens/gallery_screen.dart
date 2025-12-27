import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/constants.dart';
import '../models/coloring_image.dart';
import '../providers/gallery_provider.dart';
import '../widgets/image_card.dart';
import 'coloring_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallery'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: _buildSearchBar(),
        ),
      ),
      body: Column(
        children: [
          // Filters
          _buildFilters(),
          
          // Category chips
          _buildCategoryChips(),
          
          // Image grid
          Expanded(
            child: _buildImageGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search images...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    context.read<GalleryProvider>().setSearchQuery('');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onChanged: (value) {
          context.read<GalleryProvider>().setSearchQuery(value);
        },
      ),
    );
  }

  Widget _buildFilters() {
    return Consumer<GalleryProvider>(
      builder: (context, gallery, child) {
        return Container(
          height: 50,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: GalleryFilter.values.map((filter) {
              final isSelected = gallery.filter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        filter.icon,
                        size: 16,
                        color: isSelected ? Colors.white : AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(filter.displayName),
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (_) => gallery.setFilter(filter),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildCategoryChips() {
    return Consumer<GalleryProvider>(
      builder: (context, gallery, child) {
        return Container(
          height: 45,
          padding: const EdgeInsets.only(bottom: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // All categories chip
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('All'),
                  selected: gallery.selectedCategory == null,
                  onSelected: (_) => gallery.setCategory(null),
                ),
              ),
              // Individual category chips
              ...ImageCategory.values.map((category) {
                final isSelected = gallery.selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('${category.icon} ${category.displayName}'),
                    selected: isSelected,
                    onSelected: (_) => gallery.setCategory(
                      isSelected ? null : category,
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageGrid() {
    return Consumer<GalleryProvider>(
      builder: (context, gallery, child) {
        if (gallery.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (gallery.images.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_not_supported,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No images found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    gallery.setFilter(GalleryFilter.all);
                    gallery.setCategory(null);
                    gallery.setSearchQuery('');
                    _searchController.clear();
                  },
                  child: const Text('Clear filters'),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: gallery.images.length,
          itemBuilder: (context, index) {
            final image = gallery.images[index];
            return ImageCard(
              imageInfo: image,
              progress: gallery.getProgress(image.id),
              isFavorite: gallery.isFavorite(image.id),
              onTap: () => _navigateToColoring(image.id),
              onFavoriteToggle: () => gallery.toggleFavorite(image.id),
            );
          },
        );
      },
    );
  }

  void _navigateToColoring(String imageId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ColoringScreen(imageId: imageId),
      ),
    );
  }
}